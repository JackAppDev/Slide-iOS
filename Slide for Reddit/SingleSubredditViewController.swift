//
//  SingleSubredditViewController.swift
//  Slide for Reddit
//
//  Created by Carlos Crane on 12/22/16.
//  Copyright © 2016 Haptic Apps. All rights reserved.
//

import UIKit
import reddift
import SDWebImage
import SideMenu
import RealmSwift
import MaterialComponents.MDCActivityIndicator
import MaterialComponents.MaterialBottomSheet
import TTTAttributedLabel
import SloppySwiper
import XLActionController
import MKColorPicker
import RLBAlertsPickers

// MARK: - Base
class SingleSubredditViewController: MediaViewController {

    override var keyCommands: [UIKeyCommand]? {
        return [UIKeyCommand(input: " ", modifierFlags: [], action: #selector(spacePressed))]
    }

    let maxHeaderHeight: CGFloat = 120;
    let minHeaderHeight: CGFloat = 56;
    public var inHeadView = UIView()

    let margin: CGFloat = 10
    let cellsPerRow = 3
    
    var times = 0

    var parentController: MainViewController?
    var accentChosen: UIColor?

    var isAccent = false

    var isCollapsed = false
    var isHiding = false
    var isToolbarHidden = false

    var oldY = CGFloat(0)

    var links: [RSubmission] = []
    var paginator = Paginator()
    var sub: String
    var session: Session? = nil
    var tableView: UICollectionView = UICollectionView.init(frame: CGRect.zero, collectionViewLayout: UICollectionViewLayout.init())
    var single: Bool = false

    var loaded = false
    var sideView: UIView = UIView()
    var subb: UIButton = UIButton()

    var subInfo: Subreddit?
    var flowLayout: WrappingFlowLayout = WrappingFlowLayout.init()

    static var firstPresented = true
    static var cellVersion = 0

    var headerView = UIView()
    var more = UIButton()

    var lastY: CGFloat = CGFloat(0)
    var add: MDCFloatingButton = MDCFloatingButton()
    var hide: MDCFloatingButton = MDCFloatingButton()
    var lastYUsed = CGFloat(0)

    var listingId: String = "" //a random id for use in Realm
    static var ignoreFab = false

    static var fab: UIButton?

    var first = true
    var indicator: MDCActivityIndicator?

    var searchText: String?

    var loading = false
    var nomore = false

    var showing = false

    var sort = SettingValues.defaultSorting
    var time = SettingValues.defaultTimePeriod

    var refreshControl: UIRefreshControl!

    var savedIndex: IndexPath?
    var realmListing: RListing?

    var oldsize = CGFloat(0)

    init(subName: String, parent: MainViewController) {
        sub = subName;
        self.parentController = parent

        super.init(nibName: nil, bundle: nil)
        //  setBarColors(color: ColorUtil.getColorForSub(sub: subName))
    }

    init(subName: String, single: Bool) {
        sub = subName
        self.single = true
        super.init(nibName: nil, bundle: nil)
        // setBarColors(color: ColorUtil.getColorForSub(sub: subName))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func becomeFirstResponder() -> Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        flowLayout.delegate = self
        let frame = self.view.bounds
        self.tableView = UICollectionView(frame: CGRect.zero, collectionViewLayout: flowLayout)
        self.view = UIView.init(frame: CGRect.zero)

        self.view.addSubview(tableView)

        self.tableView.delegate = self
        self.tableView.dataSource = self
//        self.tableView.prefetchDataSource = self
        refreshControl = UIRefreshControl()

        reloadNeedingColor()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if (SubredditReorderViewController.changed) {
            self.reloadNeedingColor()
            flowLayout.reset()
            CachedTitle.titles.removeAll()
            self.tableView.reloadData()
        }

        doHeadView()

        navigationController?.toolbar.barTintColor = ColorUtil.backgroundColor

        if (single || !SettingValues.viewType) {
            navigationController?.setNavigationBarHidden(false, animated: true)
            self.navigationController?.navigationBar.shadowImage = UIImage()
            navigationController?.navigationBar.isTranslucent = false
        }

        navigationController?.navigationBar.barTintColor = ColorUtil.getColorForSub(sub: sub)

        self.automaticallyAdjustsScrollViewInsets = false
        self.edgesForExtendedLayout = UIRectEdge.all
        self.extendedLayoutIncludesOpaqueBars = true

        first = false
        tableView.delegate = self

        if (savedIndex != nil) {
            tableView.reloadItems(at: [savedIndex!])
        } else {
            tableView.reloadData()
        }

        if (single && navigationController!.modalPresentationStyle != .pageSheet) {
            // let swiper = SloppySwiper.init(navigationController: self.navigationController!)
            // self.navigationController!.delegate = swiper!
        }

        self.view.backgroundColor = ColorUtil.backgroundColor
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if(!SettingValues.bottomBarHidden || SettingValues.viewType){
            navigationController?.setToolbarHidden(false, animated: false)
            self.isToolbarHidden = false
            setupFab()
        } else {
            navigationController?.setToolbarHidden(true, animated: false)
        }

    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        tableView.frame = self.view.bounds

        if (self.view.bounds.width != oldsize) {
            oldsize = self.view.bounds.width
            flowLayout.reset()
            tableView.reloadData()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if (single || !SettingValues.viewType) {
            self.navigationController?.setNavigationBarHidden(false, animated: true)
        }

        UIApplication.shared.statusBarStyle = .lightContent

        if (single) {
            UIApplication.shared.statusBarView?.backgroundColor = .clear
        }
        if(!SingleSubredditViewController.ignoreFab){
            UIView.animate(withDuration: 0.25, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut, animations: {
                SingleSubredditViewController.fab?.transform = CGAffineTransform.identity.scaledBy(x: 0.001, y: 0.001)
            }, completion: { finished in
                SingleSubredditViewController.fab?.isHidden = true
            })
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        if(self.viewIfLoaded?.window != nil ){
            tableView.reloadData()
            setupFab()
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func getHeightFromAspectRatio(imageHeight: CGFloat, imageWidth: CGFloat, viewWidth: CGFloat) -> CGFloat {
        let ratio = imageHeight / imageWidth
        return viewWidth * ratio
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let currentY = scrollView.contentOffset.y
        if(!SettingValues.pinToolbar){
            if (currentY > lastYUsed && currentY > 60) {
                if (navigationController != nil && !isHiding && !isToolbarHidden && !(scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height))) {
                    hideUI(inHeader: true)
                }
            } else if ((currentY < lastYUsed + 20) && !isHiding && navigationController != nil && (isToolbarHidden)) {
                showUI()
            }
        }
        lastYUsed = currentY
        lastY = currentY
    }

    func hideUI(inHeader: Bool) {
        isHiding = true
        if (single || !SettingValues.viewType) {
            (navigationController)?.setNavigationBarHidden(true, animated: true)
        }
        
        UIView.animate(withDuration: 0.25, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut, animations: {
            SingleSubredditViewController.fab?.transform = CGAffineTransform.identity.scaledBy(x: 0.001, y: 0.001)
        }, completion: { finished in
            SingleSubredditViewController.fab?.isHidden = true
            self.isHiding = false
        })
        
        if(!SettingValues.bottomBarHidden || SettingValues.viewType){
            (self.navigationController)?.setToolbarHidden(true, animated: true)
        }
        self.isToolbarHidden = true

        if(!single){
            if(AutoCache.progressView != nil){
                oldY = AutoCache.progressView!.frame.origin.y
                UIView.animate(withDuration: 0.25, delay: 0.0, options: UIViewAnimationOptions.curveEaseInOut, animations: {
                    AutoCache.progressView!.frame.origin.y = self.view.frame.size.height - 56
                },completion: nil)
            }
        }
    }

    func showUI() {
        if (single || !SettingValues.viewType) {
            (navigationController)?.setNavigationBarHidden(false, animated: true)
        }

        if(!single && AutoCache.progressView != nil){
                UIView.animate(withDuration: 0.25, delay: 0.0, options: UIViewAnimationOptions.curveEaseInOut, animations: {
                    AutoCache.progressView!.frame.origin.y = self.oldY
                }, completion: { b in
                    SingleSubredditViewController.fab?.isHidden = false

                    UIView.animate(withDuration: 0.25, delay: 0.25, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut, animations: {
                        SingleSubredditViewController.fab?.transform = CGAffineTransform.identity.scaledBy(x: 1.0, y: 1.0)
                    }, completion: { finished in
                    })

                    if(!SettingValues.bottomBarHidden || SettingValues.viewType){
                        (self.navigationController)?.setToolbarHidden(false, animated: true)
                    }
                    self.isToolbarHidden = false
                })
        } else {
            SingleSubredditViewController.fab?.isHidden = false

            UIView.animate(withDuration: 0.25, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut, animations: {
                SingleSubredditViewController.fab?.transform = CGAffineTransform.identity.scaledBy(x: 1.0, y: 1.0)
            }, completion: { finished in

            })

            if(!SettingValues.bottomBarHidden || SettingValues.viewType){
                (navigationController)?.setToolbarHidden(false, animated: true)
            }
            self.isToolbarHidden = false
        }
    }

    func show(_ animated: Bool = true) {
        if (SingleSubredditViewController.fab != nil) {
            if animated == true {
                SingleSubredditViewController.fab!.isHidden = false
                UIView.animate(withDuration: 0.3, animations: { () -> Void in
                    SingleSubredditViewController.fab!.alpha = 1
                })
            } else {
                SingleSubredditViewController.fab!.isHidden = false
            }
        }
    }

    func hideFab(_ animated: Bool = true) {
        if (SingleSubredditViewController.fab != nil) {
            if animated == true {
                UIView.animate(withDuration: 0.3, animations: { () -> Void in
                    SingleSubredditViewController.fab!.alpha = 0
                }, completion: { finished in
                    SingleSubredditViewController.fab!.isHidden = true
                })
            } else {
                SingleSubredditViewController.fab!.isHidden = true
            }
        }
    }

    func setupFab() {
        if(!SettingValues.bottomBarHidden || SettingValues.viewType){
            if (SingleSubredditViewController.fab != nil && !SingleSubredditViewController.fab!.isHidden) {
                UIView.animate(withDuration: 0.15, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut, animations: {
                    SingleSubredditViewController.fab?.transform = CGAffineTransform.identity.scaledBy(x: 0.001, y: 0.001)
                }, completion: { finished in
                    SingleSubredditViewController.fab?.removeFromSuperview()
                    SingleSubredditViewController.fab = nil
                    self.addNewFab()
                })
            } else {
                if(SingleSubredditViewController.fab != nil){
                    SingleSubredditViewController.fab!.removeFromSuperview()
                    SingleSubredditViewController.fab = nil
                }
                addNewFab()
            }
        }
    }
    
    func addNewFab(){
        SingleSubredditViewController.ignoreFab = false
        if (!MainViewController.isOffline && !SettingValues.hiddenFAB) {
            SingleSubredditViewController.fab = UIButton(frame: CGRect.init(x: (UIScreen.main.bounds.width / 2) - 70, y: -20, width: 140, height: 45))
            SingleSubredditViewController.fab!.backgroundColor = ColorUtil.accentColorForSub(sub: sub)
            SingleSubredditViewController.fab!.layer.cornerRadius = 22.5
            SingleSubredditViewController.fab!.clipsToBounds = true
            var title = "  " + SettingValues.fabType.getTitle();
            SingleSubredditViewController.fab!.setTitle(title, for: .normal)
            SingleSubredditViewController.fab!.leftImage(image: (UIImage.init(named: SettingValues.fabType.getPhoto())?.navIcon())!, renderMode: UIImageRenderingMode.alwaysOriginal)
            SingleSubredditViewController.fab!.elevate(elevation: 2)
            SingleSubredditViewController.fab!.titleLabel?.textAlignment = .center
            SingleSubredditViewController.fab!.titleLabel?.font = UIFont.systemFont(ofSize: 14)
            
            var width = title.size(with: SingleSubredditViewController.fab!.titleLabel!.font).width + CGFloat(65)
            SingleSubredditViewController.fab!.frame = CGRect.init(x: (UIScreen.main.bounds.width / 2) - (width / 2), y: -20, width: width, height: CGFloat(45))
            
            SingleSubredditViewController.fab!.titleEdgeInsets = UIEdgeInsets.init(top: 0, left: 20, bottom: 0, right: 20)
            navigationController?.toolbar.addSubview(SingleSubredditViewController.fab!)
            
            SingleSubredditViewController.fab!.addTapGestureRecognizer {
                switch (SettingValues.fabType) {
                case .SIDEBAR:
                    self.doDisplaySidebar()
                    break
                case .NEW_POST:
                    self.newPost(SingleSubredditViewController.fab!)
                    break
                case .SHADOWBOX:
                    self.shadowboxMode()
                    break
                case .HIDE_READ:
                    self.hideReadPosts()
                    break
                case .GALLERY:
                    self.galleryMode()
                    break
                }
            }
            
            SingleSubredditViewController.fab!.addLongTapGestureRecognizer {
                self.changeFab()
            }
            
            SingleSubredditViewController.fab!.transform = CGAffineTransform.init(scaleX: 0.001, y: 0.001)
            UIView.animate(withDuration: 0.25, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2, options: .curveEaseInOut, animations: {
                SingleSubredditViewController.fab!.transform = CGAffineTransform.identity.scaledBy(x: 1.0, y: 1.0)
            }, completion: nil)
        }
    }

    func changeFab() {
        let actionSheetController: UIAlertController = UIAlertController(title: "Change button type", message: "", preferredStyle: .alert)

        let cancelActionButton: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { action -> Void in
            print("Cancel")
        }
        actionSheetController.addAction(cancelActionButton)

        for t in SettingValues.FabType.cases {
            let saveActionButton: UIAlertAction = UIAlertAction(title: t.getTitle(), style: .default) { action -> Void in
                UserDefaults.standard.set(t.rawValue, forKey: SettingValues.pref_fabType)
                SettingValues.fabType = t
                self.setupFab()
            }
            actionSheetController.addAction(saveActionButton)
        }

        self.present(actionSheetController, animated: true, completion: nil)
    }

    func reloadNeedingColor() {
        tableView.backgroundColor = ColorUtil.backgroundColor

        refreshControl.tintColor = ColorUtil.fontColor
        refreshControl.attributedTitle = NSAttributedString(string: "")
        refreshControl.addTarget(self, action: #selector(self.drefresh(_:)), for: UIControlEvents.valueChanged)
        tableView.addSubview(refreshControl) // not required when using UITableViewController

        self.automaticallyAdjustsScrollViewInsets = false


        // TODO: Can just use .self instead of .classForCoder()
        self.tableView.register(BannerLinkCellView.classForCoder(), forCellWithReuseIdentifier: "banner\(SingleSubredditViewController.cellVersion)")
        self.tableView.register(ThumbnailLinkCellView.classForCoder(), forCellWithReuseIdentifier: "thumb\(SingleSubredditViewController.cellVersion)")
        self.tableView.register(TextLinkCellView.classForCoder(), forCellWithReuseIdentifier: "text\(SingleSubredditViewController.cellVersion)")

        var top = 20
        if #available(iOS 11.0, *) {
            top = 0
        } else {
            top = 64
        }

        top = top + ((SettingValues.viewType && !single) ? 52 : 0)

        self.tableView.contentInset = UIEdgeInsets.init(top: CGFloat(top), left: 0, bottom: 65, right: 0)

        session = (UIApplication.shared.delegate as! AppDelegate).session

        if (SingleSubredditViewController.firstPresented && !single) || (self.links.count == 0 && !single && !SettingValues.viewType) {
            load(reset: true)
            SingleSubredditViewController.firstPresented = false
        }

        if (single) {

            let sort = UIButton.init(type: .custom)
            sort.setImage(UIImage.init(named: "ic_sort_white")?.navIcon(), for: UIControlState.normal)
            sort.addTarget(self, action: #selector(self.showSortMenu(_:)), for: UIControlEvents.touchUpInside)
            sort.frame = CGRect.init(x: 0, y: 0, width: 25, height: 25)
            let sortB = UIBarButtonItem.init(customView: sort)

            if(!SettingValues.bottomBarHidden || SettingValues.viewType){
                more = UIButton.init(type: .custom)
                more.setImage(UIImage.init(named: "moreh")?.navIcon(), for: UIControlState.normal)
                more.addTarget(self, action: #selector(self.showMoreNone(_:)), for: UIControlEvents.touchUpInside)
                more.frame = CGRect.init(x: 0, y: 0, width: 25, height: 25)
                let moreB = UIBarButtonItem.init(customView: more)
                
                navigationItem.rightBarButtonItems = [moreB, sortB]
            } else {
                more = UIButton.init(type: .custom)
                more.setImage(UIImage.init(named: "moreh")?.menuIcon(), for: UIControlState.normal)
                more.addTarget(self, action: #selector(self.showMoreNone(_:)), for: UIControlEvents.touchUpInside)
                more.frame = CGRect.init(x: 0, y: 0, width: 25, height: 25)
                let moreB = UIBarButtonItem.init(customView: more)
                
                navigationItem.rightBarButtonItems = [sortB]
                let flexButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
                
                toolbarItems = [flexButton, moreB]
            }
            title = sub

            self.sort = SettingValues.getLinkSorting(forSubreddit: self.sub)
            self.time = SettingValues.getTimePeriod(forSubreddit: self.sub)

            do {
                try (UIApplication.shared.delegate as! AppDelegate).session?.about(sub, completion: { (result) in
                    switch result {
                    case .failure:
                        print(result.error!.description)
                        DispatchQueue.main.async {
                            if (self.sub == ("all") || self.sub == ("frontpage") || self.sub.hasPrefix("/m/") || self.sub.contains("+")) {
                                self.load(reset: true)
                            } else {
                                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
                                    let alert = UIAlertController.init(title: "Subreddit not found", message: "r/\(self.sub) could not be found, is it spelled correctly?", preferredStyle: .alert)
                                    alert.addAction(UIAlertAction.init(title: "Close", style: .default, handler: { (_) in
                                        self.navigationController?.popViewController(animated: true)
                                        self.dismiss(animated: true, completion: nil)

                                    }))
                                    self.present(alert, animated: true, completion: nil)
                                }

                            }
                        }
                    case .success(let r):
                        self.subInfo = r
                        DispatchQueue.main.async {
                            if (self.subInfo!.over18 && !SettingValues.nsfwEnabled) {
                                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
                                    let alert = UIAlertController.init(title: "r/\(self.sub) is NSFW", message: "If you are 18 and willing to see adult content, enable NSFW content in Settings > Content", preferredStyle: .alert)
                                    alert.addAction(UIAlertAction.init(title: "Close", style: .default, handler: { (_) in
                                        self.navigationController?.popViewController(animated: true)
                                        self.dismiss(animated: true, completion: nil)
                                    }))
                                    self.present(alert, animated: true, completion: nil)
                                }
                            } else {
                                if (self.sub != ("all") && self.sub != ("frontpage") && !self.sub.hasPrefix("/m/")) {
                                    if (SettingValues.saveHistory) {
                                        if (SettingValues.saveNSFWHistory && self.subInfo!.over18) {
                                            Subscriptions.addHistorySub(name: AccountController.currentName, sub: self.subInfo!.displayName)
                                        } else if (!self.subInfo!.over18) {
                                            Subscriptions.addHistorySub(name: AccountController.currentName, sub: self.subInfo!.displayName)
                                        }
                                    }
                                }
                                print("Loading")
                                self.load(reset: true)
                            }

                        }
                    }
                })
            } catch {
            }
        }
    }

    func exit() {
        self.navigationController?.popViewController(animated: true)
        if (self.navigationController!.modalPresentationStyle == .pageSheet) {
            self.navigationController!.dismiss(animated: true, completion: nil)
        }
    }

    func doDisplayMultiSidebar(_ sub: Multireddit) {
        let alrController = UIAlertController(title: sub.displayName, message: sub.descriptionMd, preferredStyle: UIAlertControllerStyle.alert)
        for s in sub.subreddits {
            let somethingAction = UIAlertAction(title: "r/" + s, style: UIAlertActionStyle.default, handler: { (alert: UIAlertAction!) in
                VCPresenter.showVC(viewController: SingleSubredditViewController.init(subName: s, single: true), popupIfPossible: true, parentNavigationController: self.navigationController, parentViewController: self)
            })
            let color = ColorUtil.getColorForSub(sub: s)
            if (color != ColorUtil.baseColor) {
                somethingAction.setValue(color, forKey: "titleTextColor")

            }
            alrController.addAction(somethingAction)

        }
        var somethingAction = UIAlertAction(title: "Edit multireddit", style: UIAlertActionStyle.default, handler: { (alert: UIAlertAction!) in print("something") })
        alrController.addAction(somethingAction)

        somethingAction = UIAlertAction(title: "Delete multireddit", style: UIAlertActionStyle.destructive, handler: { (alert: UIAlertAction!) in print("something") })
        alrController.addAction(somethingAction)


        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: { (alert: UIAlertAction!) in print("cancel") })

        alrController.addAction(cancelAction)


        //todo make this work on ipad
        self.present(alrController, animated: true, completion: {})
    }

    func subscribeSingle(_ selector: AnyObject) {
        if (subChanged && !Subscriptions.isSubscriber(sub) || Subscriptions.isSubscriber(sub)) {
            //was not subscriber, changed, and unsubscribing again
            Subscriptions.unsubscribe(sub, session: session!)
            subChanged = false
            BannerUtil.makeBanner(text: "Unsubscribed", color: ColorUtil.accentColorForSub(sub: sub), seconds: 3, context: self, top: true)
            subb.setImage(UIImage.init(named: "addcircle")?.getCopy(withColor: ColorUtil.fontColor), for: UIControlState.normal)
        } else {
            let alrController = UIAlertController.init(title: "Subscribe to \(sub)", message: nil, preferredStyle: .actionSheet)
            if (AccountController.isLoggedIn) {
                let somethingAction = UIAlertAction(title: "Add to sub list and subscribe", style: UIAlertActionStyle.default, handler: { (alert: UIAlertAction!) in
                    Subscriptions.subscribe(self.sub, true, session: self.session!)
                    self.subChanged = true
                    BannerUtil.makeBanner(text: "Subscribed", color: ColorUtil.accentColorForSub(sub: self.sub), seconds: 3, context: self, top: true)
                    self.subb.setImage(UIImage.init(named: "subbed")?.getCopy(withColor: ColorUtil.fontColor), for: UIControlState.normal)
                })
                alrController.addAction(somethingAction)
            }

            let somethingAction = UIAlertAction(title: "Just add to sub list", style: UIAlertActionStyle.default, handler: { (alert: UIAlertAction!) in
                Subscriptions.subscribe(self.sub, false, session: self.session!)
                self.subChanged = true
                BannerUtil.makeBanner(text: "Added to subreddit list", color: ColorUtil.accentColorForSub(sub: self.sub), seconds: 3, context: self, top: true)
                self.subb.setImage(UIImage.init(named: "subbed")?.getCopy(withColor: ColorUtil.fontColor), for: UIControlState.normal)
            })
            alrController.addAction(somethingAction)

            let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: { (alert: UIAlertAction!) in print("cancel") })

            alrController.addAction(cancelAction)

            alrController.modalPresentationStyle = .fullScreen
            if let presenter = alrController.popoverPresentationController {
                presenter.sourceView = subb
                presenter.sourceRect = subb.bounds
            }

            self.present(alrController, animated: true, completion: {})

        }

    }

    func displayMultiredditSidebar() {
        do {
            print("Getting \(sub.substring(3, length: sub.length - 3))")
            try (UIApplication.shared.delegate as! AppDelegate).session?.getMultireddit(Multireddit.init(name: sub.substring(3, length: sub.length - 3), user: AccountController.currentName), completion: { (result) in
                switch result {
                case .success(let r):
                    DispatchQueue.main.async {
                        self.doDisplayMultiSidebar(r)
                    }
                default:
                    DispatchQueue.main.async {
                        BannerUtil.makeBanner(text: "Multireddit information not found", color: GMColor.red500Color(), seconds: 3, context: self)
                    }
                    break
                }

            })
        } catch {
        }
    }

    func hideReadPosts() {
        var indexPaths: [IndexPath] = []
        var newLinks: [RSubmission] = []

        var index = 0
        var count = 0
        for submission in links {
            if (History.getSeen(s: submission)) {
                indexPaths.append(IndexPath(row: count, section: 0))
                links.remove(at: index)
            } else {
                index += 1
            }
            count += 1
        }

        //todo save realm
        DispatchQueue.main.async {
            if(!indexPaths.isEmpty){
                self.tableView.performBatchUpdates({
                    self.tableView.deleteItems(at: indexPaths)
                    self.flowLayout.reset()
                }, completion: nil)
            }
        }
    }

    func doHeadView(){
        inHeadView.removeFromSuperview()
        inHeadView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: max(self.view.frame.size.width, self.view.frame.size.height), height: (UIApplication.shared.statusBarView?.frame.size.height ?? 20)))
        self.inHeadView.backgroundColor = ColorUtil.getColorForSub(sub: sub)
        
        if(!(navigationController is TapBehindModalViewController)){
            self.view.addSubview(inHeadView)
        }
    }
    
    func resetColors(){
        navigationController?.navigationBar.barTintColor = ColorUtil.getColorForSub(sub: sub)
        setupFab()
        if (parentController != nil) {
            parentController?.colorChanged(ColorUtil.getColorForSub(sub: sub))
        }
    }

    func reloadDataReset() {
        self.flowLayout.reset()
        tableView.reloadData()
        tableView.layoutIfNeeded()
        setupFab()
    }

    func search() {
        let alert = UIAlertController(title: "Search", message: "", preferredStyle: .alert)

        let config: TextField.Config = { textField in
            textField.becomeFirstResponder()
            textField.textColor = .black
            textField.placeholder = "Search for a post..."
            textField.left(image: UIImage.init(named: "search"), color: .black)
            textField.leftViewPadding = 12
            textField.borderWidth = 1
            textField.cornerRadius = 8
            textField.borderColor = UIColor.lightGray.withAlphaComponent(0.5)
            textField.backgroundColor = .white
            textField.keyboardAppearance = .default
            textField.keyboardType = .default
            textField.returnKeyType = .done
            textField.action { textField in
                self.searchText = textField.text
            }
        }

        alert.addOneTextField(configuration: config)

        alert.addAction(UIAlertAction(title: "Search All", style: .default, handler: { [weak alert] (_) in
            let text = self.searchText ?? ""
            let search = SearchViewController.init(subreddit: "all", searchFor: text)
            VCPresenter.showVC(viewController: search, popupIfPossible: true, parentNavigationController: self.navigationController, parentViewController: self)
        }))

        if (sub != "all" && sub != "frontpage" && sub != "friends" && !sub.startsWith("/m/")) {
            alert.addAction(UIAlertAction(title: "Search \(sub)", style: .default, handler: { [weak alert] (_) in
                let text = self.searchText ?? ""
                let search = SearchViewController.init(subreddit: self.sub, searchFor: text)
                VCPresenter.showVC(viewController: search, popupIfPossible: true, parentNavigationController: self.navigationController, parentViewController: self)
            }))
        }

        alert.addAction(UIAlertAction.init(title: "Cancel", style: .cancel, handler: nil))

        present(alert, animated: true, completion: nil)

    }
    
    func doDisplaySidebar() {
        Sidebar.init(parent: self, subname: self.sub).displaySidebar()
    }

    func filterContent() {
        let alert = UIAlertController(title: "Content to hide on", message: "r/\(sub)", preferredStyle: .alert)

        let settings = Filter(subreddit: sub, parent: self)

        alert.addAction(UIAlertAction.init(title: "Close", style: .cancel, handler: nil))
        alert.setValue(settings, forKey: "contentViewController")
        present(alert, animated: true, completion: nil)
    }

    func galleryMode() {
        if(!VCPresenter.proDialogShown(feature: true, self)){
            let controller = GalleryTableViewController()
            var gLinks: [RSubmission] = []
            for l in links {
                if l.banner {
                    gLinks.append(l)
                }
            }
            controller.setLinks(links: gLinks)
            controller.modalPresentationStyle = .overFullScreen
            present(controller, animated: true, completion: nil)
        }
    }

    func shadowboxMode() {
        if(!VCPresenter.proDialogShown(feature: true, self) && !links.isEmpty){
            let controller = ShadowboxViewController.init(submissions: links, subreddit: sub)
            controller.modalPresentationStyle = .overFullScreen
            present(controller, animated: true, completion: nil)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func loadMore() {
        if (!showing) {
            showLoader()
        }
        load(reset: false)
    }

    func showLoader() {
        showing = true
        //todo maybe?
    }

    func showSortMenu(_ selector: UIView?) {
        let actionSheetController: UIAlertController = UIAlertController(title: "Sorting", message: "", preferredStyle: .actionSheet)

        let cancelActionButton: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { action -> Void in
            print("Cancel")
        }
        actionSheetController.addAction(cancelActionButton)

        let selected = UIImage.init(named: "selected")!.getCopy(withSize: .square(size: 20), withColor: .blue)

        for link in LinkSortType.cases {
            let saveActionButton: UIAlertAction = UIAlertAction(title: link.description, style: .default) { action -> Void in
                self.showTimeMenu(s: link, selector: selector)
            }
            if (sort == link) {
                saveActionButton.setValue(selected, forKey: "image")
            }
            actionSheetController.addAction(saveActionButton)
        }

        if let presenter = actionSheetController.popoverPresentationController {
            presenter.sourceView = selector!
            presenter.sourceRect = selector!.bounds
        }

        self.present(actionSheetController, animated: true, completion: nil)

    }

    func showTimeMenu(s: LinkSortType, selector: UIView?) {
        if (s == .hot || s == .new) {
            sort = s
            refresh()
            return
        } else {
            let actionSheetController: UIAlertController = UIAlertController(title: "Sorting", message: "", preferredStyle: .actionSheet)

            let cancelActionButton: UIAlertAction = UIAlertAction(title: "Close", style: .cancel) { action -> Void in
            }
            actionSheetController.addAction(cancelActionButton)

            let selected = UIImage.init(named: "selected")!.getCopy(withSize: .square(size: 20), withColor: .blue)

            for t in TimeFilterWithin.cases {
                let saveActionButton: UIAlertAction = UIAlertAction(title: t.param, style: .default) { action -> Void in
                    print("Sort is \(s) and time is \(t)")
                    self.sort = s
                    self.time = t
                    self.refresh()
                }
                if (time == t) {
                    saveActionButton.setValue(selected, forKey: "image")
                }

                actionSheetController.addAction(saveActionButton)
            }

            if let presenter = actionSheetController.popoverPresentationController {
                presenter.sourceView = selector!
                presenter.sourceRect = selector!.bounds
            }

            self.present(actionSheetController, animated: true, completion: nil)
        }
    }

    func refresh() {
        links = []
        tableView.reloadData()
        flowLayout.reset()
        flowLayout.invalidateLayout()
        load(reset: true)
    }

    func deleteSelf(_ cell: LinkCellView) {
        do {
            try session?.deleteCommentOrLink(cell.link!.getId(), completion: { (stream) in
                DispatchQueue.main.async {
                    if (self.navigationController!.modalPresentationStyle == .formSheet) {
                        self.navigationController!.dismiss(animated: true)
                    } else {
                        self.navigationController!.popViewController(animated: true)
                    }
                }
            })
        } catch {

        }
    }

    func load(reset: Bool) {
        if (!loading) {
            if (!loaded) {
                if (indicator == nil) {
                    indicator = MDCActivityIndicator.init(frame: CGRect.init(x: CGFloat(0), y: CGFloat(0), width: CGFloat(80), height: CGFloat(80)))
                    indicator?.strokeWidth = 5
                    indicator?.radius = 15
                    indicator?.indicatorMode = .indeterminate
                    indicator?.cycleColors = [ColorUtil.getColorForSub(sub: sub), ColorUtil.accentColorForSub(sub: sub)]
                    let center = CGPoint.init(x: UIScreen.main.bounds.width / 2, y: 50 + UIScreen.main.bounds.height / 2)
                    indicator?.center = center
                    self.tableView.addSubview(indicator!)
                    indicator?.startAnimating()
                }
            }
            loaded = true

            do {
                loading = true
                if (reset) {
                    paginator = Paginator()
                }
                var subreddit: SubredditURLPath = Subreddit.init(subreddit: sub)

                if (sub.hasPrefix("/m/")) {
                    subreddit = Multireddit.init(name: sub.substring(3, length: sub.length - 3), user: AccountController.currentName)
                }

                try session?.getList(paginator, subreddit: subreddit, sort: sort, timeFilterWithin: time, completion: { (result) in
                    switch result {
                    case .failure:
                        //test if realm exists and show that
                        DispatchQueue.main.async {
                            print("Getting realm data")
                            do {
                                let realm = try Realm()
                                var updated = NSDate()
                                if let listing = realm.objects(RListing.self).filter({ (item) -> Bool in
                                    return item.subreddit == self.sub
                                }).first {
                                    self.links = []
                                    for i in listing.links {
                                        self.links.append(i)
                                    }
                                    updated = listing.updated
                                }
                                var paths = [IndexPath]()
                                for i in 0...(self.links.count - 1) {
                                    paths.append(IndexPath.init(item: i, section: 0))
                                }

                                self.flowLayout.reset()
                                self.tableView.reloadData()
                                self.tableView.contentOffset = CGPoint.init(x: 0, y: -64 + ((SettingValues.viewType && !self.single) ? -20 : 0))

                                self.refreshControl.endRefreshing()
                                self.indicator?.stopAnimating()
                                self.loading = false
                                self.loading = false
                                self.nomore = true

                                if (self.links.isEmpty) {
                                    BannerUtil.makeBanner(text: "No offline content found! You can set up subreddit caching in Settings > Auto Cache", color: ColorUtil.accentColorForSub(sub: self.sub), seconds: 5, context: self)
                                } else {
                                    BannerUtil.makeBanner(text: "Showing offline content (\(DateFormatter().timeSince(from: updated, numericDates: true)))", color: ColorUtil.accentColorForSub(sub: self.sub), seconds: 3, context: self)
                                }
                            } catch {

                            }
                        }
                        print(result.error!)
                    case .success(let listing):

                        if (reset) {
                            self.links = []
                        }
                        let before = self.links.count
                        if (self.realmListing == nil) {
                            self.realmListing = RListing()
                            self.realmListing!.subreddit = self.sub
                            self.realmListing!.updated = NSDate()
                        }
                        if (reset && self.realmListing!.links.count > 0) {
                            self.realmListing!.links.removeAll()
                        }

                        let newLinks = listing.children.flatMap({ $0 as? Link })
                        var converted: [RSubmission] = []
                        for link in newLinks {
                            let newRS = RealmDataWrapper.linkToRSubmission(submission: link)
                            converted.append(newRS)
                            CachedTitle.addTitle(s: newRS)
                        }
                        let values = PostFilter.filter(converted, previous: self.links, baseSubreddit: self.sub)
                        self.links += values
                        self.paginator = listing.paginator
                        self.nomore = !listing.paginator.hasMore() || values.isEmpty
                        do {
                            let realm = try! Realm()
                            //todo insert
                            realm.beginWrite()
                            for submission in self.links {
                                realm.create(type(of: submission), value: submission, update: true)
                                self.realmListing!.links.append(submission)
                            }
                            realm.create(type(of: self.realmListing!), value: self.realmListing!, update: true)
                            try realm.commitWrite()
                        } catch {

                        }
                        self.preloadImages(values)
                        DispatchQueue.main.async {
                            if(self.links.isEmpty){
                                self.flowLayout.reset()
                                self.tableView.reloadData()
                                
                                self.refreshControl.endRefreshing()
                                self.indicator?.stopAnimating()
                                self.loading = false
                                if(MainViewController.first){
                                    MainViewController.first = false
                                    self.parentController?.checkForMail()
                                }
                                BannerUtil.makeBanner(text: "No posts found! Check your filter settings", color: GMColor.red500Color(), seconds: 5, context: self)
                            } else {
                                var paths = [IndexPath]()
                                for i in before...(self.links.count - 1) {
                                    paths.append(IndexPath.init(item: i, section: 0))
                                }

                                if (before == 0) {
                                    self.flowLayout.reset()
                                    self.tableView.reloadData()
                                    var top = CGFloat(0)
                                    if #available(iOS 11, *){
                                        top += 22
                                        if((!SettingValues.viewType)){
                                            top += 4
                                        }
                                    }
                                
                                    self.tableView.contentOffset = CGPoint.init(x: 0, y: -18 + (-1 * ((SettingValues.viewType && !self.single) ?    (52 ) : (self.navigationController?.navigationBar.frame.size.height ?? 64))) - top)
                                } else {
                                    self.tableView.insertItems(at: paths)
                                    self.flowLayout.reset()
                                }

                                self.refreshControl.endRefreshing()
                                self.indicator?.stopAnimating()
                                self.loading = false
                                if(MainViewController.first){
                                    MainViewController.first = false
                                    self.parentController?.checkForMail()
                                }
                                
                            }
                        }
                    }
                })
            } catch {
                print(error)
            }

        }
    }


    func preloadImages(_ values: [RSubmission]) {
        var urls: [URL] = []
        if(!SettingValues.noImages){
        for submission in values {
            var thumb = submission.thumbnail
            var big = submission.banner
            var height = submission.height
            if(submission.url != nil){
            var type = ContentType.getContentType(baseUrl: submission.url)
            if (submission.isSelf) {
                type = .SELF
            }

            if (thumb && type == .SELF) {
                thumb = false
            }

            let fullImage = ContentType.fullImage(t: type)

            if (!fullImage && height < 50) {
                big = false
                thumb = true
            } else if (big && (SettingValues.postImageMode == .CROPPED_IMAGE)) {
                height = 200
            }

            if (type == .SELF && SettingValues.hideImageSelftext || SettingValues.hideImageSelftext && !big || type == .SELF) {
                big = false
                thumb = false
            }

            if (height < 50) {
                thumb = true
                big = false
            }

            let shouldShowLq = SettingValues.dataSavingEnabled && submission.lQ && !(SettingValues.dataSavingDisableWiFi && LinkCellView.checkWiFi())
            if (type == ContentType.CType.SELF && SettingValues.hideImageSelftext
                    || SettingValues.noImages && submission.isSelf) {
                big = false
                thumb = false
            }

            if (big || !submission.thumbnail) {
                thumb = false
            }

            if (!big && !thumb && submission.type != .SELF && submission.type != .NONE) {
                thumb = true
            }

            if (thumb && !big) {
                if (submission.thumbnailUrl == "nsfw") {
                } else if (submission.thumbnailUrl == "web" || submission.thumbnailUrl.isEmpty) {
                } else {
                    if let url = URL.init(string: submission.thumbnailUrl) {
                        urls.append(url)
                    }
                }
            }

            if (big) {
                if (shouldShowLq) {
                    if let url = URL.init(string: submission.lqUrl) {
                        urls.append(url)
                    }

                } else {
                    if let url = URL.init(string: submission.bannerUrl) {
                        urls.append(url)
                    }
                }
            }
            }
        }
        SDWebImagePrefetcher.init().prefetchURLs(urls)
        }
    }

    // TODO: This is mostly replicated by `RSubmission.getLinkView()`. Can we consolidate?
    func cellType(forSubmission submission: RSubmission) -> CurrentType {
        var target: CurrentType = .none

        var thumb = submission.thumbnail
        var big = submission.banner
        let height = submission.height

        var type = ContentType.getContentType(baseUrl: submission.url)
        if (submission.isSelf) {
            type = .SELF
        }

        if (SettingValues.postImageMode == .THUMBNAIL) {
            big = false
            thumb = true
        }

        let fullImage = ContentType.fullImage(t: type)

        if (!fullImage && height < 50) {
            big = false
            thumb = true
        }

        if (type == .SELF && SettingValues.hideImageSelftext || SettingValues.hideImageSelftext && !big) {
            big = false
            thumb = false
        }

        if (height < 50) {
            thumb = true
            big = false
        }

        if (type == ContentType.CType.SELF && SettingValues.hideImageSelftext
            || SettingValues.noImages && submission.isSelf) {
            big = false
            thumb = false
        }

        if (big || !submission.thumbnail) {
            thumb = false
        }


        if (!big && !thumb && submission.type != .SELF && submission.type != .NONE) { //If a submission has a link but no images, still show the web thumbnail
            thumb = true
        }

        if (submission.nsfw && (!SettingValues.nsfwPreviews || SettingValues.hideNSFWCollection && (sub == "all" || sub == "frontpage" || sub.contains("/m/") || sub.contains("+") || sub == "popular"))) {
            big = false
            thumb = true
        }

        if (SettingValues.noImages) {
            big = false
            thumb = false
        }
        if (thumb && type == .SELF) {
            thumb = false
        }

        if (thumb && !big) {
            target = .thumb
        } else if (big) {
            target = .banner
        } else {
            target = .text
        }

        if(type == .LINK && SettingValues.linkAlwaysThumbnail){
            target = .thumb
        }

        return target
    }

}

// MARK: - Actions
extension SingleSubredditViewController {

    @objc func spacePressed() {
        UIView.animate(withDuration: 0.2, delay: 0, options: UIViewAnimationOptions.curveEaseOut, animations: {
            self.tableView.contentOffset.y = self.tableView.contentOffset.y + 350
        }, completion: nil)
    }

    func drefresh(_ sender: AnyObject) {
        refresh()
    }

    func showMoreNone(_ sender: AnyObject) {
        showMore(sender, parentVC: nil)
    }

    func hideAll(_ sender: AnyObject) {
        for submission in links {
            if (History.getSeen(s: submission)) {
                let index = links.index(of: submission)!
                links.remove(at: index)
            }
        }
        tableView.reloadData()
        self.flowLayout.reset()
    }

    func pickTheme(sender: AnyObject?, parent: MainViewController?) {
        parentController = parent
        let alertController = UIAlertController(title: "\n\n\n\n\n\n\n\n", message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)

        isAccent = false
        let margin: CGFloat = 10.0
        let rect = CGRect(x: margin, y: margin, width: UIScreen.main.traitCollection.userInterfaceIdiom == .pad ? 314 - margin * 4.0: alertController.view.bounds.size.width - margin * 4.0, height: 150)
        let MKColorPicker = ColorPickerView.init(frame: rect)
        MKColorPicker.scrollToPreselectedIndex = true
        MKColorPicker.delegate = self
        MKColorPicker.colors = GMPalette.allColor()
        MKColorPicker.selectionStyle = .check
        MKColorPicker.scrollDirection = .vertical
        MKColorPicker.style = .circle

        var baseColor = ColorUtil.getColorForSub(sub: sub).toHexString()
        var index = 0
        for color in GMPalette.allColor() {
            if (color.toHexString() == baseColor) {
                break
            }
            index += 1
        }

        MKColorPicker.preselectedIndex = index

        alertController.view.addSubview(MKColorPicker)

        /*todo maybe ?alertController.addAction(image: UIImage.init(named: "accent"), title: "Custom color", color: ColorUtil.accentColorForSub(sub: sub), style: .default, isEnabled: true) { (action) in
         if(!VCPresenter.proDialogShown(feature: false, self)){
         let alert = UIAlertController.init(title: "Choose a color", message: nil, preferredStyle: .actionSheet)
         alert.addColorPicker(color: (self.navigationController?.navigationBar.barTintColor)!, selection: { (c) in
         ColorUtil.setColorForSub(sub: self.sub, color: (self.navigationController?.navigationBar.barTintColor)!)
         self.reloadDataReset()
         self.navigationController?.navigationBar.barTintColor = c
         UIApplication.shared.statusBarView?.backgroundColor = c
         self.sideView.backgroundColor = c
         self.add.backgroundColor = c
         self.sideView.backgroundColor = c
         if (self.parentController != nil) {
         self.parentController?.colorChanged()
         }
         })
         alert.addAction(UIAlertAction.init(title: "Cancel", style: .cancel, handler: { (action) in
         self.pickTheme(sender: sender, parent: parent)
         }))
         self.present(alert, animated: true)
         }

         }*/

        alertController.addAction(image: UIImage(named: "colors"), title: "Accent color", color: ColorUtil.accentColorForSub(sub: sub), style: .default) { action in
            ColorUtil.setColorForSub(sub: self.sub, color: (self.navigationController?.navigationBar.barTintColor)!)
            self.pickAccent(sender: sender, parent: parent)
            self.reloadDataReset()
        }

        alertController.addAction(image: nil, title: "Save", color: ColorUtil.accentColorForSub(sub: sub), style: .default) { action in
            ColorUtil.setColorForSub(sub: self.sub, color: (self.navigationController?.navigationBar.barTintColor)!)
            self.reloadDataReset()
            if (self.parentController != nil) {
                self.parentController?.colorChanged(ColorUtil.getColorForSub(sub: self.sub))
            }
        }


        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (alert: UIAlertAction!) in
            self.resetColors()
        })

        alertController.addAction(cancelAction)

        alertController.modalPresentationStyle = .popover
        if let presenter = alertController.popoverPresentationController {
            presenter.sourceView = sender as! UIButton
            presenter.sourceRect = (sender as! UIButton).bounds
        }

        present(alertController, animated: true, completion: nil)
    }

    func pickAccent(sender: AnyObject?, parent: MainViewController?) {
        parentController = parent
        let alertController = UIAlertController(title: "\n\n\n\n\n\n\n\n", message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)

        isAccent = true
        let margin: CGFloat = 10.0
        let rect = CGRect(x: margin, y: margin, width: UIScreen.main.traitCollection.userInterfaceIdiom == .pad ? 314 - margin * 4.0: alertController.view.bounds.size.width - margin * 4.0, height: 150)
        let MKColorPicker = ColorPickerView.init(frame: rect)
        MKColorPicker.scrollToPreselectedIndex = true
        MKColorPicker.delegate = self
        MKColorPicker.colors = GMPalette.allColorAccent()
        MKColorPicker.selectionStyle = .check
        MKColorPicker.scrollDirection = .vertical
        MKColorPicker.style = .circle

        var baseColor = ColorUtil.accentColorForSub(sub: sub).toHexString()
        var index = 0
        for color in GMPalette.allColorAccent() {
            if (color.toHexString() == baseColor) {
                break
            }
            index += 1
        }

        MKColorPicker.preselectedIndex = index

        alertController.view.addSubview(MKColorPicker)


        alertController.addAction(image: UIImage(named: "palette"), title: "Primary color", color: ColorUtil.accentColorForSub(sub: sub), style: .default) { action in
            ColorUtil.setAccentColorForSub(sub: self.sub, color: self.accentChosen!)
            self.pickTheme(sender: sender, parent: parent)
            self.reloadDataReset()
        }

        alertController.addAction(image: nil, title: "Save", color: ColorUtil.accentColorForSub(sub: sub), style: .default) { action in
            ColorUtil.setAccentColorForSub(sub: self.sub, color: self.accentChosen!)
            self.reloadDataReset()
            if (self.parentController != nil) {
                self.parentController?.colorChanged(ColorUtil.getColorForSub(sub: self.sub))
            }
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (alert: UIAlertAction!) in
            self.resetColors()
        })

        alertController.addAction(cancelAction)

        alertController.modalPresentationStyle = .popover
        if let presenter = alertController.popoverPresentationController {
            presenter.sourceView = sender as! UIButton
            presenter.sourceRect = (sender as! UIButton).bounds
        }

        present(alertController, animated: true, completion: nil)
    }

    func newPost(_ sender: AnyObject) {
        PostActions.showPostMenu(self, sub: self.sub)
    }

    func showMore(_ sender: AnyObject, parentVC: MainViewController? = nil) {

        let alertController: BottomSheetActionController = BottomSheetActionController()
        alertController.headerData = "r/\(sub)"


        alertController.addAction(Action(ActionData(title: "Search", image: UIImage(named: "search")!.menuIcon()), style: .default, handler: { action in
            self.search()
        }))

        if(!single && SettingValues.viewType){
            alertController.addAction(Action(ActionData(title: "Sort (currently \(sort.path))", image: UIImage(named: "filter")!.menuIcon()), style: .default, handler: { action in
                self.showSortMenu(self.more)
            }))
        }

        if (sub.contains("/m/")) {
            alertController.addAction(Action(ActionData(title: "Manage multireddit", image: UIImage(named: "info")!.menuIcon()), style: .default, handler: { action in
                self.displayMultiredditSidebar()
            }))
        } else {
            alertController.addAction(Action(ActionData(title: "Sidebar", image: UIImage(named: "info")!.menuIcon()), style: .default, handler: { action in
                self.doDisplaySidebar()
            }))
        }

        alertController.addAction(Action(ActionData(title: "Refresh", image: UIImage(named: "sync")!.menuIcon()), style: .default, handler: { action in
            self.refresh()
        }))

        alertController.addAction(Action(ActionData(title: "Gallery", image: UIImage(named: "image")!.menuIcon()), style: .default, handler: { action in
            self.galleryMode()
        }))

        alertController.addAction(Action(ActionData(title: "Shadowbox", image: UIImage(named: "shadowbox")!.menuIcon()), style: .default, handler: { action in
            self.shadowboxMode()
        }))

        alertController.addAction(Action(ActionData(title: "Subreddit theme", image: UIImage(named: "colors")!.menuIcon()), style: .default, handler: { action in
            if (parentVC != nil) {
                let p = (parentVC!)
                self.pickTheme(sender: sender, parent: p)
            } else {
                self.pickTheme(sender: sender, parent: nil)
            }
        }))

        if ((sub != "all" && sub != "frontpage" && !sub.contains("+") && !sub.contains("/m/"))) {
            alertController.addAction(Action(ActionData(title: "Submit", image: UIImage(named: "edit")!.menuIcon()), style: .default, handler: { action in
                self.newPost(sender)
            }))
        }

        alertController.addAction(Action(ActionData(title: "Filter content", image: UIImage(named: "filter")!.menuIcon()), style: .default, handler: { action in
            if(!self.links.isEmpty || self.loaded){
                self.filterContent()
            }
        }))

        VCPresenter.presentAlert(alertController, parentVC: self)

    }

}

// MARK: - Collection View Delegate
extension SingleSubredditViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if (SettingValues.markReadOnScroll) {
            History.addSeen(s: links[indexPath.row])
        }
    }

}

// MARK: - Collection View Data Source
extension SingleSubredditViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return links.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let submission = self.links[(indexPath as NSIndexPath).row]

        var cell: LinkCellView!

        switch cellType(forSubmission: submission) {
        case .thumb:
            cell = tableView.dequeueReusableCell(withReuseIdentifier: "thumb\(SingleSubredditViewController.cellVersion)", for: indexPath) as! ThumbnailLinkCellView
        case .banner:
            cell = tableView.dequeueReusableCell(withReuseIdentifier: "banner\(SingleSubredditViewController.cellVersion)", for: indexPath) as! BannerLinkCellView
        default:
            cell = tableView.dequeueReusableCell(withReuseIdentifier: "text\(SingleSubredditViewController.cellVersion)", for: indexPath) as! TextLinkCellView
        }

        cell.preservesSuperviewLayoutMargins = false
        cell.del = self
        cell.layer.shouldRasterize = true
        cell.layer.rasterizationScale = UIScreen.main.scale

        cell.configure(submission: submission, parent: self, nav: self.navigationController, baseSub: self.sub)

        if indexPath.row == self.links.count - 3 && !loading && !nomore {
            self.loadMore()
        }

        return cell
    }

}

// MARK: - Collection View Prefetching Data Source
//extension SingleSubredditViewController: UICollectionViewDataSourcePrefetching {
//    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
//        // TODO: Implement
//    }
//}

// MARK: - Link Cell View Delegate
extension SingleSubredditViewController: LinkCellViewDelegate {

    func openComments(id: String, subreddit: String?) {
        var index = 0
        for s in links {
            if (s.getId() == id) {
                break
            }
            index += 1
        }
        var newLinks: [RSubmission] = []
        for i in index...links.count - 1 {
            newLinks.append(links[i])
        }

        if (self.splitViewController != nil && UIScreen.main.traitCollection.userInterfaceIdiom == .pad && !SettingValues.multiColumn) {
            let comment = CommentViewController.init(submission: newLinks[0])
            let nav = UINavigationController.init(rootViewController: comment)
            self.splitViewController?.showDetailViewController(nav, sender: self)
        } else {
            let comment = PagingCommentViewController.init(submissions: newLinks)
            VCPresenter.showVC(viewController: comment, popupIfPossible: true, parentNavigationController: self.navigationController, parentViewController: self)
        }
    }
}

// MARK: - Color Picker View Delegate
extension SingleSubredditViewController: ColorPickerViewDelegate {
    public func colorPickerView(_ colorPickerView: ColorPickerView, didSelectItemAt indexPath: IndexPath) {
        if (isAccent) {
            accentChosen = colorPickerView.colors[indexPath.row]
            SingleSubredditViewController.fab?.backgroundColor = accentChosen
        } else {
            let c = colorPickerView.colors[indexPath.row]
            self.navigationController?.navigationBar.barTintColor = c
            sideView.backgroundColor = c
            add.backgroundColor = c
            sideView.backgroundColor = c
            inHeadView.backgroundColor = c
            if (parentController != nil) {
                parentController?.colorChanged(c)
            }
        }
    }
}

// MARK: - Wrapping Flow Layout Delegate
extension SingleSubredditViewController: WrappingFlowLayoutDelegate {
    func collectionView(_ collectionView: UICollectionView, width: CGFloat, indexPath: IndexPath) -> CGSize {
        var itemWidth = width
        if (indexPath.row < links.count) {
            let submission = links[indexPath.row]

            var thumb = submission.thumbnail
            var big = submission.banner

            var submissionHeight = CGFloat(submission.height)

            var type =  ContentType.getContentType(baseUrl: submission.url)
            if (submission.isSelf) {
                type = .SELF
            }

            if (SettingValues.postImageMode == .THUMBNAIL) {
                big = false
                thumb = true
            }

            let fullImage = ContentType.fullImage(t: type)

            if (!fullImage && submissionHeight < 50) {
                big = false
                thumb = true
            } else if (big && (( SettingValues.postImageMode == .CROPPED_IMAGE))) {
                submissionHeight = 200
            } else if (big) {
                let h = getHeightFromAspectRatio(imageHeight: submissionHeight, imageWidth: CGFloat(submission.width), viewWidth: itemWidth  - ((SettingValues.postViewMode != .CARD) ? CGFloat(5) : CGFloat(0)))
                if (h == 0) {
                    submissionHeight = 200
                } else {
                    submissionHeight = h
                }
            }

            if (type == .SELF && SettingValues.hideImageSelftext || SettingValues.hideImageSelftext && !big) {
                big = false
                thumb = false
            }

            if (submissionHeight < 50) {
                thumb = true
                big = false
            }

            let shouldShowLq = SettingValues.dataSavingEnabled && submission.lQ && !(SettingValues.dataSavingDisableWiFi && LinkCellView.checkWiFi())
            if (type == ContentType.CType.SELF && SettingValues.hideImageSelftext
                || SettingValues.noImages && submission.isSelf) {
                big = false
                thumb = false
            }

            if (big || !submission.thumbnail) {
                thumb = false
            }

            if (submission.nsfw && (!SettingValues.nsfwPreviews || SettingValues.hideNSFWCollection && (sub == "all" || sub == "frontpage" || sub.contains("/m/") || sub.contains("+") || sub == "popular"))) {
                big = false
                thumb = true
            }

            if (SettingValues.noImages) {
                big = false
                thumb = false
            }

            if (thumb && type == .SELF) {
                thumb = false
            }

            if (!big && !thumb && submission.type != .SELF && submission.type != .NONE) { //If a submission has a link but no images, still show the web thumbnail
                thumb = true
            }

            if(type == .LINK && SettingValues.linkAlwaysThumbnail) {
                thumb = true
                big = false
            }

            if (big) {
                let imageSize = CGSize.init(width: submission.width, height: ((SettingValues.postImageMode == .CROPPED_IMAGE)) ? 200 : submission.height)

                var aspect = imageSize.width / imageSize.height
                if (aspect == 0 || aspect > 10000 || aspect.isNaN) {
                    aspect = 1
                }
                if ((SettingValues.postImageMode == .CROPPED_IMAGE)) {
                    aspect = width / 200
                    if (aspect == 0 || aspect > 10000 || aspect.isNaN) {
                        aspect = 1
                    }

                    submissionHeight = 200
                }
            }
            var paddingTop = CGFloat(0)
            var paddingBottom = CGFloat(2)
            var paddingLeft = CGFloat(0)
            var paddingRight = CGFloat(0)
            var innerPadding = CGFloat(0)
            if (SettingValues.postViewMode == .CARD || SettingValues.postViewMode == .CENTER) {
                paddingTop = 5
                paddingBottom = 5
                paddingLeft = 5
                paddingRight = 5
            }

            let actionbar = CGFloat(SettingValues.actionBarMode != .FULL ? 0 : 24)

            let thumbheight = (SettingValues.largerThumbnail ? CGFloat(75) : CGFloat(50)) - (SettingValues.postViewMode == .COMPACT ? 15 : 0)
            let textHeight = CGFloat(submission.isSelf ? 5 : 0)

            if (thumb) {
                innerPadding += (SettingValues.postViewMode == .COMPACT ? 8 : 12) //between top and thumbnail
                if(SettingValues.actionBarMode == .FULL){
                    innerPadding += 18 - (SettingValues.postViewMode == .COMPACT ? 4 : 0) //between label and bottom box
                    innerPadding += (SettingValues.postViewMode == .COMPACT ? 4 : 8) //between box and end
                } else {
                    innerPadding += (SettingValues.postViewMode == .COMPACT ? 8 : 12) //between thumbnail and bottom
                }
            } else if (big) {
                if (SettingValues.postViewMode == .CENTER) {
                    innerPadding += (SettingValues.postViewMode == .COMPACT ? 8 : 16) //between label
                    if(SettingValues.actionBarMode == .FULL){
                        innerPadding += (SettingValues.postViewMode == .COMPACT ? 8 : 12) //between banner and box
                    } else {
                        innerPadding += (SettingValues.postViewMode == .COMPACT ? 8 : 12) //between buttons and bottom
                    }
                } else {
                    innerPadding += (SettingValues.postViewMode == .COMPACT ? 4 : 8) //between banner and label
                    if(SettingValues.actionBarMode == .FULL){
                        innerPadding += (SettingValues.postViewMode == .COMPACT ? 8 : 12) //between label and box
                    } else {
                        innerPadding += (SettingValues.postViewMode == .COMPACT ? 8 : 12) //between buttons and bottom
                    }
                }
                if(SettingValues.actionBarMode == .FULL){
                    innerPadding += (SettingValues.postViewMode == .COMPACT ? 4 : 8) //between box and end
                }
            } else {
                if(!submission.body.trimmed().isEmpty() && SettingValues.showFirstParagraph){
                    innerPadding += (SettingValues.postViewMode == .COMPACT ? 4 : 8)
                }
                innerPadding += (SettingValues.postViewMode == .COMPACT ? 16 : 24) //between top and title
                if(SettingValues.actionBarMode == .FULL){
                    innerPadding += (SettingValues.postViewMode == .COMPACT ? 8 : 12) //between body and box
                    innerPadding += (SettingValues.postViewMode == .COMPACT ? 4 : 8) //between box and end
                }
            }

            var estimatedUsableWidth = itemWidth - paddingLeft - paddingRight
            if (thumb) {
                estimatedUsableWidth -= thumbheight //is the same as the width
                estimatedUsableWidth -= (SettingValues.postViewMode == .COMPACT ? 16 : 24) //between edge and thumb
                estimatedUsableWidth -= (SettingValues.postViewMode == .COMPACT ? 4 : 8) //between thumb and label
            } else {
                estimatedUsableWidth -= (SettingValues.postViewMode == .COMPACT ? 16 : 24) //12 padding on either side
            }

            if(SettingValues.postImageMode == .CROPPED_IMAGE) {
                submissionHeight = 200
            } else {
                submissionHeight = getHeightFromAspectRatio(imageHeight: submissionHeight == 200 ? CGFloat(200) : CGFloat(submission.height), imageWidth: CGFloat(submission.width), viewWidth: estimatedUsableWidth)
            }
            var imageHeight = big && !thumb ? CGFloat(submissionHeight) : CGFloat(0)

            if(thumb){
                imageHeight = thumbheight
            }

            if(SettingValues.actionBarMode.isSide()){
                estimatedUsableWidth -= 36
                estimatedUsableWidth -= (SettingValues.postViewMode == .COMPACT ? 12 : 20) //buttons horizontal margins
            }

            let framesetter = CTFramesetterCreateWithAttributedString(CachedTitle.getTitle(submission: submission, full: false, false))
            let textSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(), nil, CGSize.init(width: estimatedUsableWidth, height: CGFloat.greatestFiniteMagnitude), nil)
            let totalHeight = paddingTop + paddingBottom + (thumb ? max((SettingValues.actionBarMode.isSide() ? max(ceil(textSize.height), 60) : ceil(textSize.height)), imageHeight) : (SettingValues.actionBarMode.isSide() ? max(ceil(textSize.height), 60) : ceil(textSize.height)) + imageHeight) + innerPadding + actionbar + textHeight
            return CGSize(width: itemWidth, height: totalHeight)
        }
        return CGSize(width: itemWidth, height: 0)
    }
}

// MARK: - Submission More Delegate
extension SingleSubredditViewController: SubmissionMoreDelegate {
    func reply(_ cell: LinkCellView) {

    }

    func save(_ cell: LinkCellView) {
        do {
            try session?.setSave(!ActionStates.isSaved(s: cell.link!), name: (cell.link?.getId())!, completion: { (result) in

            })
            ActionStates.setSaved(s: cell.link!, saved: !ActionStates.isSaved(s: cell.link!))
            History.addSeen(s: cell.link!)
            cell.refresh()
        } catch {

        }
    }

    func upvote(_ cell: LinkCellView) {
        do {
            try session?.setVote(ActionStates.getVoteDirection(s: cell.link!) == .up ? .none : .up, name: (cell.link?.getId())!, completion: { (result) in

            })
            ActionStates.setVoteDirection(s: cell.link!, direction: ActionStates.getVoteDirection(s: cell.link!) == .up ? .none : .up)
            History.addSeen(s: cell.link!)
            cell.refresh()
        } catch {

        }
    }

    func downvote(_ cell: LinkCellView) {
        do {
            try session?.setVote(ActionStates.getVoteDirection(s: cell.link!) == .down ? .none : .down, name: (cell.link?.getId())!, completion: { (result) in

            })
            ActionStates.setVoteDirection(s: cell.link!, direction: ActionStates.getVoteDirection(s: cell.link!) == .down ? .none : .down)
            History.addSeen(s: cell.link!)
            cell.refresh()
        } catch {

        }
    }

    func hide(_ cell: LinkCellView) {
        do {
            try session?.setHide(true, name: cell.link!.getId(), completion: { (result) in })
            let id = cell.link!.getId()
            var location = 0
            var item = links[0]
            for submission in links {
                if (submission.getId() == id) {
                    item = links[location]
                    print("Removing link")
                    links.remove(at: location)
                    break
                }
                location += 1
            }

            tableView.performBatchUpdates({
                self.tableView.deleteItems(at: [IndexPath.init(item: location, section: 0)])
                BannerUtil.makeBanner(text: "Submission hidden forever, tap to undo", color: GMColor.red500Color(), seconds: 4, context: self, callback: {
                    self.links.insert(item, at: location)
                    self.tableView.insertItems(at: [IndexPath.init(item: location, section: 0)])
                    do {
                        try self.session?.setHide(false, name: cell.link!.getId(), completion: { (result) in })
                    } catch {

                    }
                })

                self.flowLayout.reset()
            }, completion: nil)

        } catch {

        }
    }

    func more(_ cell: LinkCellView) {
        PostActions.showMoreMenu(cell: cell, parent: self, nav: self.navigationController!, mutableList: true, delegate: self)
    }

    func mod(_ cell: LinkCellView) {
        PostActions.showModMenu(cell, parent: self)
    }

    func showFilterMenu(_ cell: LinkCellView) {
        let link = cell.link!
        let actionSheetController: UIAlertController = UIAlertController(title: "What would you like to filter?", message: "", preferredStyle: .alert)

        var cancelActionButton: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { action -> Void in
            print("Cancel")
        }
        actionSheetController.addAction(cancelActionButton)

        cancelActionButton = UIAlertAction(title: "Posts by u/\(link.author)", style: .default) { action -> Void in
            PostFilter.profiles.append(link.author as NSString)
            PostFilter.saveAndUpdate()
            self.links = PostFilter.filter(self.links, previous: nil, baseSubreddit: self.sub)
            self.reloadDataReset()
        }
        actionSheetController.addAction(cancelActionButton)

        cancelActionButton = UIAlertAction(title: "Posts from r/\(link.subreddit)", style: .default) { action -> Void in
            PostFilter.subreddits.append(link.subreddit as NSString)
            PostFilter.saveAndUpdate()
            self.links = PostFilter.filter(self.links, previous: nil, baseSubreddit: self.sub)
            self.reloadDataReset()
        }
        actionSheetController.addAction(cancelActionButton)

        cancelActionButton = UIAlertAction(title: "Posts linking to \(link.domain)", style: .default) { action -> Void in
            PostFilter.domains.append(link.domain as NSString)
            PostFilter.saveAndUpdate()
            self.links = PostFilter.filter(self.links, previous: nil, baseSubreddit: self.sub)
            self.reloadDataReset()
        }
        actionSheetController.addAction(cancelActionButton)

        //todo make this work on ipad
        self.present(actionSheetController, animated: true, completion: nil)

    }
}
