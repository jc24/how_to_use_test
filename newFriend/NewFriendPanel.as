package friends.newFriend 
{
	import app._G;
	import bbtcontrol.button.BBTTabButton;
	import bbtcontrol.button.QHButton;
	import bbtcontrol.panel.QHClickPanel;
	import bbtcontrol.window.UIWindow;
	import control.label.BaseLabel;
	import control.list.BaseList;
	import control.list.IListItem;
	import control.panel.BasePanel;
	import control.tab.TabListItem;
	import control.window.BaseWindow;
	import download.LoadFactory;
	import fl.containers.ScrollPane;
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.TextEvent;
	import friends.friendsEx.AddFriendWindow;
	import friends.friendsEx.DialogPanel;
	import friends.friendsEx.FriendEventManager;
	import friends.friendsEx.FriendItem;
	import friends.friendsEx.ListenerPanel;
	import guide.MCManager;
	import helper.DDataEvent;
	import maincity.BottomButton;
	import net.ByteBuffer;
	import net.MsgProxy;
	import win.CMainUICol;
	/**
	 * 新好友面板
	 * @author jc
	 */
	public class NewFriendPanel extends BaseWindow
	{
		private var m_netProxy:MsgProxy;
		private var m_facLoader:LoadFactory;
		private var m_friendList:BaseList;
		private var m_player:BBTPlayer;
		private var m_roleInfo:RoleInfo;
		private var m_isChange:Boolean;
		private var m_tabList:BaseList;
		private var m_friendItems:Vector.<IListItem>;
		private var m_addFriendBtn:QHButton;
		private var m_listenerLabel:BaseLabel;
		private var m_scrollPanel:ScrollPane;
		private var m_addFriendWindow:AddFriendWindow;
		private var m_listenerPanel:ListenerPanel;
		private var m_friendAllData:Object = {};   //1:附近 2:好友 3:黑名单
		
		public function NewFriendPanel() 
		{
			super(220, 435, null, new QHButton(QHButton.STYLE1), BasePanel.DIALOGBOX);
			m_netProxy = _G.net;
			m_facLoader = _G.newLoader();
			m_facLoader.addEventListener(Event.COMPLETE,init);
			m_facLoader.beginLoadSwfObject("lib/socialres.swf");
		    m_player   = _G.data["player"] as BBTPlayer;
            m_roleInfo = m_player.roleInfo;
			
			//_G.event.addEventListener("REFRESH_FRIEND_PANEL",refreshPlayerList);			
		}
		//
		//private function refreshPlayerList(e:DDataEvent):void 
		//{
			//TODO 切换到好友的tab页刷
			//m_isChange = true;
			//m_tabList.selectIndex(0);
		//}
		
		private function init(e:Event):void
		{
			m_facLoader.removeEventListener(Event.COMPLETE,init);
			//初始化的时候，把标志设置成true
			//m_isChange 	= true;
			
			m_friendItems = new Vector.<IListItem>;
			
			//毫无意义的背景图
			var bg:BasePanel = new BasePanel(196, 258, null, BasePanel.LABELGRID);
			bg.move(13,126);
			addChild(bg);
			
			//玩家头像
			var headIcon:MovieClip;
			headIcon = CMainUICol.getInst().head.getFace(m_player);
			addChild(headIcon);
			headIcon.x = 20;
			headIcon.y = 35;
			
			//玩家昵称
			var nameLable:BaseLabel = new BaseLabel();
			nameLable.showBorder(true,0x000000);
			nameLable.htmlText = _G.R("<B><font color = '#ffffff' size = '12' face = 'SimSun'>" + m_player.nick + "</font></B>");
			addChild(nameLable);
			nameLable.move(85, 40);
			
			//加好友按钮
			m_addFriendBtn = new QHButton(QHButton.STYLE2, _G.R("加好友"));
			addChild( m_addFriendBtn );
			m_addFriendBtn.move( 65, 386 );
			m_addFriendBtn.addEventListener("BUTTON_CLICK", onClickAddFriendBtn);
			
			m_listenerLabel = new BaseLabel();
			m_listenerLabel.setMouseEnable(true);
			m_listenerLabel.showBorder(true, 0x141414);
			addChild(m_listenerLabel);
			m_listenerLabel.htmlText = "<font color='#2dc82d'>" + "<a href=\"event:\"><u>" + _G.R("我的听众") + "</u></a>" + "</font>";		
			m_listenerLabel.addEventListener(TextEvent.LINK, onTextLink);
			m_listenerLabel.move(85,70);
			
			//初始化好友名单列表
			initFriendList();
			//初始化tab页按钮
			initTabs();	
			
			allowDebugDrag();
		}
		
		private function initTabs():void
		{
			//初始化Tab按钮
			var tabBtnList:Vector.<IListItem> = new Vector.<IListItem>();
            var friendTabBtn:BBTTabButton = new BBTTabButton(2,null,null,1,BBTTabButton.SMALLER);
            friendTabBtn.setText(_G.R("好友"));
          
            var nearTabBtn:BBTTabButton = new BBTTabButton(1,null,null,1,BBTTabButton.SMALLER);
            nearTabBtn.setText(_G.R("最近"));
          
			var blackListTabBtn:BBTTabButton = new BBTTabButton(3,null,null,1,BBTTabButton.SMALLER);
            blackListTabBtn.setText(_G.R("屏蔽"));
			
            tabBtnList.push(new TabListItem(friendTabBtn));
            tabBtnList.push(new TabListItem(nearTabBtn));
			tabBtnList.push(new TabListItem(blackListTabBtn));
			
            m_tabList = new BaseList(3,61,0); 
            m_tabList.setItems(tabBtnList);
            addChild( m_tabList );     
			
			getAllData();
			
			m_tabList.move(20, 105);  
            m_tabList.addEventListener( "SELECT_CHANGED",refreshTabBtnList); 
			m_tabList.selectIndex(0); 
		}
		
		private function refreshTabBtnList(e:DDataEvent):void 
		{
			//TODO 切换tab页会刷新数据
			var tab_id:int = ((e.data as TabListItem).tabButton as BBTTabButton ).classId;
			//DTrace.traceex("tab页切换了" + tab_id);
			addToPanel(tab_id);
		}
		
		private function findAndTween(pid:Number):Boolean
		{
			for (var i:int = 1; i <= 3 ; ++i )
			{
				for each (var item:Object in m_friendAllData[i]) 
				{
					if (pid == item["friend_id"])
					{
						addToPanel(item["group_id"])
						tweenFriend(pid)
					}
				}
			}			
		}
		
		public function tweenFriend(pid:Number):void
		{
			for each (var item:FriendItem in m_friendList.items) 
			{
				if (item.pid == pid) 
				{
					item.tween();
					break;
				}
			}			
		}
		
		//public function tweenFiend(pid:Number):void
		//{
			//if (m_friendList) 
			//{
				//当前列表找不到 切换
				//if (findAndTween(pid) == false) 
				//{
					//if (m_friendList.items == m_friendItems)
					//{
						//切换到最近联系人分页和
						//m_tabList.selectIndex(1);
						//m_friendList.setItems(m_nearItems)
					//}
					//else
					//{
						//m_tabList.selectIndex(0);
						//m_friendList.setItems(m_friendItems)						
					//}
					//切换后再找
					//var reFind:Boolean = findAndTween(pid);
					//
					//已经刷新过找了，返回
					//if (freshFlag == true) 
					//{
						//freshFlag = false;
						//return;
					//}
					//未更新过 并且 还找不到 更新数据 再找
					//if (reFind == false && freshFlag == false)
					//{
						//m_findPid = pid;
						//refreshPlayerList(null);
					//}
				//}		
			//}
		//}
		
		private function getAllData():void
		{
			m_netProxy.sendLoginMsg("GET_ALL_FRIENDS_STATE",function(outBuf:ByteBuffer):void{}, 
			  function(inBuf:ByteBuffer):void
			  {    
				for (var i:int = 1; i <= 3 ; ++i )
				{
					var number:int = inBuf.readInt();
					var playerData:Object = new Object();
					for (var count:int = 0; count < number ; ++count )
					{
						var data:Object = new Object();
						data["group_id"] 		= inBuf.readInt();
						data["friend_id"] 		= Number(inBuf.readString());
						data["friend_name"] 	= inBuf.readString();
						data["player_type"] 	= inBuf.readInt();
						data["friend_level"] 	= inBuf.readInt();
						data["cur_state"] 		= inBuf.readInt();
						playerData[count] = data;
					}
					m_friendAllData[i] = playerData
				}
				addToPanel(2);
			  });				
		}
		
		private function addToPanel(index:int):void
		{
			var items:Vector.<IListItem> = new Vector.<IListItem>;	
			
			for each(var player_info:Object in m_friendAllData[index])
			{
				var item:FriendItem = new FriendItem(m_facLoader);
				item.pid 		= player_info["friend_id"];
				item.level 		= player_info["friend_level"];
				item.nick 		= player_info["friend_name"];
				item.playerType = player_info["player_type"];
				item.groupId 	= player_info["group_id"];
				item.isOnline	= player_info["cur_state"];
				items.push(item);
			}
			
			sortPlayers(items);
			m_friendList.setItems(items);
			m_scrollPanel.update();
			
			//if (freshFlag == true) tweenFiend(m_findPid);
			//tweenAllFiends();			
		}
		
		private function sortPlayers(curitems:Vector.<IListItem>):void 
		{
			//对玩家列表进行排序，排序规则在线优先于下线，等级高的优先于等级低的
			curitems.sort(function(a:IListItem,b:IListItem):int
			{
				var player1:FriendItem = a as FriendItem;
				var player2:FriendItem = b as FriendItem;
				
				if (player1.isOnline > player2.isOnline) return -1;
				else if(player1.isOnline < player2.isOnline) return 1;
				else if (player1.isOnline == player2.isOnline)
				{
					if (player1.level > player2.level)return -1;	
					else if(player1.level < player2.level)return 1;
					else return 0;
				}
				else return 0;
			});
		}
		
		private function initFriendList():void 
		{
			//初始化好友名单列表
			m_friendList = new BaseList(1, 0, 20);
			m_friendList.addEventListener("ITEM_CLICK",onFriendItemClick);
			addChild(m_friendList);
			
			m_scrollPanel = new ScrollPane();
			m_scrollPanel.setSize(180, 237); 
			  
			m_scrollPanel.x = 15;
			m_scrollPanel.y = 134;
			m_scrollPanel.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):void { 
				e.stopPropagation(); //DTrace.traceex("禁止冒泡事件 防止拖动"); 
				} );
			addChild(m_scrollPanel);
			
			m_scrollPanel.source = m_friendList;
		}
		
		private function onClickAddFriendBtn(e:DDataEvent):void 
		{
			//TODO 加好友
			if (m_addFriendWindow == null) 
			{
				m_addFriendWindow = new AddFriendWindow();
				m_addFriendWindow.addEventListener("AddFriendWindow:AddFriend",onAddFriend); 
			}
			UIWindow.getInst().showAnimationWindow(m_addFriendWindow, x + (width - m_addFriendWindow.width) / 2, y + (height - m_addFriendWindow.height) / 2);
			m_addFriendWindow.move(x + (width - m_addFriendWindow.width) / 2, y + (height - m_addFriendWindow.height) / 2);
			/*UITools.autoFedeIn(m_addFriendWindow);*/
		}
		
		private function onAddFriend(e:DDataEvent):void 
		{
			FriendEventManager.addFriend(e.data.nick);
			m_addFriendWindow.close();
		}
		
		private function onFriendItemClick(e:DDataEvent):void 
		{
			var curItem:FriendItem = e.data as FriendItem;
			if (curItem.isTween) 
			{			
				//把来消息提醒去掉
				var disp:DisplayObject = MCManager.getKeyMc("FUNCTIONZONE_FRIEND");
				(disp as BottomButton).removeFriendTip();
				
				curItem.endTween();
				var dialog:DialogPanel = FriendEventManager.getInst().getdialog(curItem.pid,curItem.nick,curItem.playerType);
				UIWindow.getInst().showAnimationWindow(dialog);
				dialog.move(dialog.stage.stageWidth/2 - dialog.width/2,dialog.stage.stageHeight/2 - dialog.height/2)
				dialog.addMSgs();
			}
			else
			{
				QHClickPanel.add(this,curItem.pid,curItem.nick);
			}
		}
		
		private function onTextLink(e:TextEvent):void 
		{
			if (m_listenerPanel != null) 
			{
				//UITools.autoReleaseDisplayObj(m_listenerPanel);
				m_listenerPanel.destroy();
			}			
			
			if (m_listenerPanel == null)
			{
				m_listenerPanel = new ListenerPanel();
			}
			if(m_listenerPanel.parent == null)
				UIWindow.getInst().showAnimationWindow(m_listenerPanel);
		}
		
		private function allowDebugDrag():void
		{
			addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
			addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		}
			
		private function onMouseUp(e:MouseEvent):void 
		{
			this.stopDrag();
		}
		
		private function onMouseDown(e:MouseEvent):void 
		{
			this.startDrag();
			e.stopPropagation();
		}
	}

}