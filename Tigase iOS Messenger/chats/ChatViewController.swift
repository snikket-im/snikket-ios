//
// ChatViewController.swift
//
// Tigase iOS Messenger
// Copyright (C) 2016 "Tigase, Inc." <office@tigase.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License,
// or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. Look for COPYING file in the top folder.
// If not, see http://www.gnu.org/licenses/.
//


import UIKit
import TigaseSwift

class ChatViewController : BaseChatViewController, UITableViewDataSource, UITableViewDelegate, EventHandler, CachedViewControllerProtocol, BaseChatViewController_ShareImageExtension, BaseChatViewController_PreviewExtension {
    
    var titleView: ChatTitleView!;
    
    let log: Logger = Logger();
    var scrollToIndexPath: IndexPath? = nil;
    
    var dataSource: ChatDataSource!;
    var cachedDataSource: CachedViewDataSourceProtocol {
        return dataSource as CachedViewDataSourceProtocol;
    }
    
    var refreshControl: UIRefreshControl!;
    var syncInProgress = false;
    
    @IBOutlet var shareButton: UIButton!;
    @IBOutlet var progressBar: UIProgressView!;
    var imagePickerDelegate: BaseChatViewController_ShareImagePickerDelegate?;
        
    override func viewDidLoad() {
        dataSource = ChatDataSource(controller: self);
        scrollDelegate = self;
        super.viewDidLoad()
        self.initialize();
        tableView.dataSource = self;
        tableView.delegate = self;
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        let navBarHeight = self.navigationController!.navigationBar.frame.size.height;
        let width = CGFloat(220);

        titleView = ChatTitleView(width: width, height: navBarHeight);
        titleView.name = navigationItem.title;
        
        let buddyBtn = UIButton(type: .system);
        buddyBtn.frame = CGRect(x: 0, y: 0, width: width, height: navBarHeight);
        buddyBtn.addSubview(titleView);
        
        buddyBtn.addTarget(self, action: #selector(ChatViewController.showBuddyInfo), for: .touchDown);
        self.navigationItem.titleView = buddyBtn;

        self.refreshControl = UIRefreshControl();
        self.refreshControl?.addTarget(self, action: #selector(ChatViewController.refreshChatHistory), for: UIControlEvents.valueChanged);
        self.tableView.addSubview(refreshControl);
        initSharing();
    }
    
    func showBuddyInfo(_ button: UIButton) {
        print("open buddy info!");
        let navigation = storyboard?.instantiateViewController(withIdentifier: "ContactViewNavigationController") as! UINavigationController;
        let contactView = navigation.visibleViewController as! ContactViewController;
        contactView.account = account;
        contactView.jid = jid.bareJid;
        navigation.title = self.navigationItem.title;
        self.showDetailViewController(navigation, sender: self);

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.newMessage), name: DBChatHistoryStore.MESSAGE_NEW, object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.avatarChanged), name: AvatarManager.AVATAR_CHANGED, object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(accountStateChanged), name: XmppService.ACCOUNT_STATE_CHANGED, object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(messageUpdated), name: DBChatHistoryStore.MESSAGE_UPDATED, object: nil);
        xmppService.registerEventHandler(self, for: PresenceModule.ContactPresenceChanged.TYPE, RosterModule.ItemUpdatedEvent.TYPE);
        
        self.updateTitleView();

        let presenceModule: PresenceModule? = xmppService.getClient(forJid: account)?.modulesManager.getModule(PresenceModule.ID);
        titleView.status = presenceModule?.presenceStore.getBestPresence(for: jid.bareJid);
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self);
        super.viewDidDisappear(animated);
        
        xmppService.unregisterEventHandler(self, for: PresenceModule.ContactPresenceChanged.TYPE, RosterModule.ItemUpdatedEvent.TYPE);
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1;
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if dataSource.numberOfMessages == 0 {
            let label = UILabel(frame: CGRect(x: 0, y:0, width: self.view.bounds.size.width, height: self.view.bounds.size.height));
            label.text = "No messages available. Pull up to refresh message history.";
            label.numberOfLines = 0;
            label.textAlignment = .center;
            label.transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0);
            label.sizeToFit();
            self.tableView.backgroundView = label;
        }
        return dataSource.numberOfMessages;
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = dataSource.getItem(for: indexPath);
        let incoming = item.state.direction == .incoming;
        let id = incoming ? "ChatTableViewCellIncoming" : "ChatTableViewCellOutgoing";
        let cell: ChatTableViewCell = tableView.dequeueReusableCell(withIdentifier: id, for: indexPath) as! ChatTableViewCell;
        cell.transform = cachedDataSource.inverted ? CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0) : CGAffineTransform.identity;
        cell.avatarView?.image = self.xmppService.avatarManager.getAvatar(for: self.jid.bareJid, account: self.account);
        cell.setValues(data: item.data, ts: item.timestamp, id: item.id, state: item.state, preview: item.preview, downloader: self.downloadPreview);
        cell.setNeedsUpdateConstraints();
        cell.updateConstraintsIfNeeded();
        
        return cell;
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        print("accessory button cliecked at", indexPath)
        let item = dataSource.getItem(for: indexPath);
        print("cliked message with id", item.id);
        guard item.data != nil else {
            return;
        }
        
        self.xmppService.dbChatHistoryStore.getMessageError(msgId: item.id) { error in
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Details", message: error ?? "Unknown error occurred", preferredStyle: .alert);
                alert.addAction(UIAlertAction(title: "Resend", style: .default, handler: {(action) in
                    print("resending message with body", item.data);
                    self.sendMessage(body: item.data!, additional: [], completed: nil);
                }));
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil));
                self.present(alert, animated: true, completion: nil);
            }
        }
    }
    
    @IBAction func shareClicked(_ sender: UIButton) {
        self.showPhotoSelector(sender);
    }
    
    func updateItem(msgId: Int, handler: @escaping (BaseChatViewController_PreviewExtension_PreviewAwareItem) -> Void) {
        DispatchQueue.main.async {
            if let indexPath = self.dataSource.getIndexPath(withId: msgId) {
                let item = self.dataSource.getItem(for: indexPath);
                handler(item);
                self.tableView.reloadRows(at: [indexPath], with: .automatic);
            }
        }
    }
    
    class ChatViewItem: CachedViewDataSourceItem, BaseChatViewController_PreviewExtension_PreviewAwareItem {
        let id: Int;
        var state: DBChatHistoryStore.State;
        let data: String?;
        let timestamp: Date;
        var preview: String?;
        
        init(cursor: DBCursor) {
            id = cursor["id"]!;
            state = DBChatHistoryStore.State(rawValue: cursor["state"]!)!;
            data = cursor["data"];
            timestamp = cursor["timestamp"]!;
            preview = cursor["preview"];
        }
        
    }
    
    func handle(event: Event) {
        switch event {
        case let cpc as PresenceModule.ContactPresenceChanged:
            guard cpc.presence.from?.bareJid == self.jid.bareJid && cpc.sessionObject.userBareJid == account else {
                return;
            }
            
            DispatchQueue.main.async() {
                self.titleView.status = cpc.presence;
            }
        case let e as RosterModule.ItemUpdatedEvent:
            guard e.sessionObject.userBareJid != nil && e.rosterItem != nil else {
                return;
            }
            guard e.sessionObject.userBareJid! == self.account && e.rosterItem!.jid.bareJid == self.jid.bareJid else {
                return;
            }
            DispatchQueue.main.async {
                self.titleView.name = e.rosterItem!.name ?? e.rosterItem!.jid.stringValue;
            }
        default:
            break;
        }
    }
    
    func newMessage(_ notification: NSNotification) {
        guard ((notification.userInfo?["account"] as? BareJID) == account) && ((notification.userInfo?["sender"] as? BareJID) == jid.bareJid) else {
            return;
        }
        
        let ts: Date = notification.userInfo!["timestamp"] as! Date;
        guard notification.userInfo?["fromArchive"] as? Bool ?? false == false else {
            if !self.syncInProgress {
                cachedDataSource.reset();
                tableView.reloadData();
            }
            return;
        }
        
        self.newItemAdded(timestamp: ts);

        if let state = notification.userInfo?["state"] as? DBChatHistoryStore.State {
            if state == .incoming_unread {
                self.xmppService.dbChatHistoryStore.markAsRead(for: account, with: jid.bareJid);
            }
        }
    }
    
    func avatarChanged(_ notification: NSNotification) {
        guard ((notification.userInfo?["jid"] as? BareJID) == jid.bareJid) else {
            return;
        }
        if let indexPaths = tableView.indexPathsForVisibleRows {
            tableView.reloadRows(at: indexPaths, with: .none);
        }
    }
    
    func accountStateChanged(_ notification: Notification) {
        let account = notification.userInfo!["account"]! as! String;
        if self.account.stringValue == account {
            updateTitleView();
        }
    }
    
    func messageUpdated(_ notification: Notification) {
        guard let data = notification.userInfo else {
            return;
        }
        guard let id = data["message-id"] as? Int else {
            return;
        }
        updateItem(msgId: id) { (item) in
            if let state = data["state"] as? DBChatHistoryStore.State {
                (item as? ChatViewItem)?.state = state;
                if state == DBChatHistoryStore.State.outgoing_error_unread {
                    DispatchQueue.global(qos: .background).async {
                        self.xmppService.dbChatHistoryStore.markAsRead(for: self.account, with: self.jid.bareJid);
                    }
                }
            }
            if data.keys.contains("preview") {
                (item as? ChatViewItem)?.preview = data["preview"] as? String;
            }
        }
    }
    
    fileprivate func updateTitleView() {
        let state = xmppService.getClient(forJid: self.account)?.state;
        DispatchQueue.main.async {
            self.titleView.connected = state != nil && state == .connected;
        }
    }
    
    @objc func refreshChatHistory() {
        let syncPeriod = AccountSettings.MessageSyncPeriod(account.stringValue).getDouble();
        guard syncPeriod != 0 else {
            self.refreshControl.endRefreshing();
            return;
        }

        let date = Date().addingTimeInterval(syncPeriod * -60.0 * 60);
        syncInProgress = true;
        syncHistory(start: date);
    }
    
    func syncHistory(start: Date, rsm rsmQuery: RSM.Query? = nil) {
        guard let mamModule: MessageArchiveManagementModule = self.xmppService.getClient(forJid: self.account)?.modulesManager.getModule(MessageArchiveManagementModule.ID) else {
            syncInProgress = false;
            self.refreshControl.endRefreshing();
            return;
        }
        
        mamModule.queryItems(with: jid, start: start, queryId: "sync-2", rsm: rsmQuery ?? RSM.Query(lastItems: 100), onSuccess: {(queryid,complete,rsmResponse) in
            self.log("received items from archive", queryid, complete, rsmResponse);
            if rsmResponse != nil && rsmResponse!.index != 0 && rsmResponse?.first != nil {
                self.syncHistory(start: start, rsm: rsmResponse?.previous(100));
            } else {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
                    self.cachedDataSource.reset();
                    self.syncInProgress = false;
                    self.tableView.reloadData();
                    self.refreshControl.endRefreshing();
                }
            }
        }, onError: {(error,stanza) in
            self.log("failed to retrieve items from archive", error, stanza);
            DispatchQueue.main.async {
                self.cachedDataSource.reset();
                self.syncInProgress = false;
                self.tableView.reloadData();
                self.refreshControl.endRefreshing();
            }
        });
    }
    
    @IBAction func sendClicked(_ sender: UIButton) {
        let text = messageField.text;
        guard !(text?.isEmpty != false) else {
            return;
        }
        
        sendMessage(body: messageField.text!, additional: [], completed: {() in
            DispatchQueue.main.async {
                self.messageField.text = nil;
            }
        });
    }
    
    func sendMessage(body: String, additional: [Element], preview: String? = nil, completed: (()->Void)?) {
        let client = xmppService.getClient(forJid: account);
        if client != nil && client!.state == .connected {
            DispatchQueue.global(qos: .default).async {
                let messageModule: MessageModule? = client?.modulesManager.getModule(MessageModule.ID);
                if let chat = messageModule?.chatManager.getChat(with: self.jid, thread: nil) {
                    let msg = chat.createMessage(body, type: .chat, subject: nil, additionalElements: additional);
                    if msg.id == nil {
                        msg.id = UUID().uuidString;
                    }
                    if Settings.MessageDeliveryReceiptsEnabled.getBool() {
                        msg.messageDelivery = MessageDeliveryReceiptEnum.request;
                    }
                    client?.context.writer?.write(msg);
                    self.xmppService.dbChatHistoryStore.appendMessage(for: client!.sessionObject, message: msg, preview: preview);
                }
            }
            completed?();
        } else {
            var alert: UIAlertController? = nil;
            if client == nil {
                alert = UIAlertController.init(title: "Warning", message: "Account is disabled.\nDo you want to enable account?", preferredStyle: .alert);
                alert?.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil));
                alert?.addAction(UIAlertAction(title: "Yes", style: .default, handler: {(alertAction) in
                    if let account = AccountManager.getAccount(forJid: self.account.stringValue) {
                        account.active = true;
                        AccountManager.updateAccount(account);
                    }
                }));
            } else if client?.state != .connected {
                alert = UIAlertController.init(title: "Warning", message: "Account is disconnected.\nPlease wait until account will reconnect", preferredStyle: .alert);
                alert?.addAction(UIAlertAction(title: "OK", style: .default, handler: nil));
            }
            if alert != nil {
                self.present(alert!, animated: true, completion: nil);
            }
        }
    }
    
    class ChatDataSource: CachedViewDataSource<ChatViewItem> {
        
        fileprivate let getMessagesStmt: DBStatement!;
        
        weak var controller: ChatViewController?;
        
        init(controller: ChatViewController) {
            self.controller = controller;
            self.getMessagesStmt = controller.xmppService.dbChatHistoryStore.getMessagesStatementForAccountAndJid();
        }
        
        override func getItemsCount() -> Int {
            return controller!.xmppService.dbChatHistoryStore.countMessages(for: controller!.account, with: controller!.jid.bareJid);
        }
        
        override func loadData(offset: Int, limit: Int, forEveryItem: (ChatViewItem)->Void) {
            controller!.xmppService.dbChatHistoryStore.forEachMessage(stmt: getMessagesStmt, account: controller!.account, jid: controller!.jid.bareJid, limit: limit, offset: offset, forEach: { (cursor)-> Void in
                forEveryItem(ChatViewItem(cursor: cursor));
            });
        }
        
    }
    
    class ChatTitleView: UIView {
        
        let nameView: UILabel!;
        let statusView: UILabel!;
        let statusHeight: CGFloat!;
        
        var name: String? {
            get {
                return nameView.text;
            }
            set {
                nameView.text = newValue;
            }
        }
        
        var connected: Bool = false {
            didSet {
                guard oldValue != connected else {
                    return;
                }
                refresh();
            }
        }
        
        var status: Presence? {
            didSet {
                self.refresh();
            }
        }
        
        init(width: CGFloat, height: CGFloat) {
            let spacing = (height * 0.23) / 3;
            statusHeight = height * 0.32;
            nameView = UILabel(frame: CGRect(x: 0, y: spacing, width: width, height: height * 0.48));
            statusView = UILabel(frame: CGRect(x: 0, y: (height * 0.44) + (spacing * 2), width: width, height: statusHeight));
            super.init(frame: CGRect(x: 0, y: 0, width: width, height: height));
            
            
            var font = nameView.font;
            font = font?.withSize((font?.pointSize)!);
            nameView.font = font;
            nameView.textAlignment = .center;
            nameView.adjustsFontSizeToFitWidth = true;
            
            font = statusView.font;
            font = font?.withSize((font?.pointSize)! - 5);
            statusView.font = font;
            statusView.textAlignment = .center;
            statusView.adjustsFontSizeToFitWidth = true;
            
            self.isUserInteractionEnabled = false;
            
            self.addSubview(nameView);
            self.addSubview(statusView);
        }
        
        required init?(coder aDecoder: NSCoder) {
            statusHeight = nil;
            statusView = nil;
            nameView = nil;
            super.init(coder: aDecoder);
        }
        
        fileprivate func refresh() {
            if connected {
                let statusIcon = NSTextAttachment();
                statusIcon.image = AvatarStatusView.getStatusImage(status?.show);
                statusIcon.bounds = CGRect(x: 0, y: -3, width: statusHeight, height: statusHeight);
                var desc = status?.status;
                if desc == nil {
                    let show = status?.show;
                    if show == nil {
                        desc = "Offline";
                    } else {
                        switch(show!) {
                        case .online:
                            desc = "Online";
                        case .chat:
                            desc = "Free for chat";
                        case .away:
                            desc = "Be right back";
                        case .xa:
                            desc = "Away";
                        case .dnd:
                            desc = "Do not disturb";
                        }
                    }
                }
                let statusText = NSMutableAttributedString(attributedString: NSAttributedString(attachment: statusIcon));
                statusText.append(NSAttributedString(string: desc!));
                statusView.attributedText = statusText;
            } else {
                statusView.text = "\u{26A0} Not connected!";
            }
        }
    }
}
