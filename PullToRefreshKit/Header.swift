//
//  PullToRefreshHeader.swift
//  PullToRefreshKit
//
//  Created by huangwenchen on 16/7/11.
//  I refer a lot logic for MJRefresh https://github.com/CoderMJLee/MJRefresh ,thanks to this lib and all contributors.
//  Copyright © 2016年 Leo. All rights reserved.
//

import Foundation
import UIKit


enum RefreshKitHeaderText{
    case pullToRefresh
    case releaseToRefresh
    case refreshSuccess
    case refreshError
    case refreshFailure
    case refreshing
}

class DefaultRefreshHeader:UIView,RefreshableHeader{
    let spinner:UIActivityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
    let textLabel:UILabel = UILabel(frame: CGRectMake(0,0,120,40))
    let imageView:UIImageView = UIImageView(frame: CGRectZero)
    private var textDic = [RefreshKitHeaderText:String]()
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(spinner)
        addSubview(textLabel)
        addSubview(imageView);
        imageView.image = UIImage(named: "arrow_down");
        imageView.sizeToFit()
        imageView.frame = CGRectMake(0, 0, 24, 24)
        imageView.center = CGPointMake(frame.width/2 - 60 - 20, frame.size.height/2)
        spinner.center = imageView.center
        
        textLabel.center = CGPointMake(frame.size.width/2, frame.size.height/2);
        textLabel.font = UIFont.systemFontOfSize(14)
        textLabel.textAlignment = .Center
        self.hidden = true
        //Default text
        textDic[.pullToRefresh] = PullToRefreshKitHeaderString.pullToRefresh
        textDic[.releaseToRefresh] = PullToRefreshKitHeaderString.releaseToRefresh
        textDic[.refreshSuccess] = PullToRefreshKitHeaderString.refreshSuccess
        textDic[.refreshError] = PullToRefreshKitHeaderString.refreshError
        textDic[.refreshFailure] = PullToRefreshKitHeaderString.refreshFailure
        textDic[.refreshing] = PullToRefreshKitHeaderString.refreshing
        textLabel.text = textDic[.pullToRefresh]
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    func setText(text:String,mode:RefreshKitHeaderText){
        textDic[mode] = text
    }
    // MARK: - Refreshable  -
    func distanceToRefresh() -> CGFloat {
        return PullToRefreshKitConst.defaultHeaderHeight
    }
    func percentageChangedDuringDragging(percent:CGFloat){
        self.hidden = !(percent > 0.0)
        if percent > 1.0{
            textLabel.text = textDic[.releaseToRefresh]
            guard CGAffineTransformEqualToTransform(self.imageView.transform, CGAffineTransformIdentity)  else{
                return
            }
            UIView.animateWithDuration(0.4, animations: {
                self.imageView.transform = CGAffineTransformMakeRotation(CGFloat(-M_PI+0.000001))
            })
        }
        if percent <= 1.0{
            textLabel.text = textDic[.pullToRefresh]
            guard CGAffineTransformEqualToTransform(self.imageView.transform, CGAffineTransformMakeRotation(CGFloat(-M_PI+0.000001)))  else{
                return
            }
            UIView.animateWithDuration(0.4, animations: {
                self.imageView.transform = CGAffineTransformIdentity
            })
        }
    }
    func willEndRefreshing(result:RefreshResult) {
        spinner.stopAnimating()
        imageView.transform = CGAffineTransformIdentity
        imageView.hidden = false
        switch result {
        case .Success:
            textLabel.text = textDic[.refreshSuccess]
        case .Error:
            textLabel.text = textDic[.refreshError]
        case .Failure:
            textLabel.text = textDic[.refreshFailure]
        case .None:
            textLabel.text = textDic[.pullToRefresh]
        }
    }
    func didEndRefreshing(result:RefreshResult) {
        textLabel.text = textDic[.pullToRefresh]
        self.hidden = true
    }
    func willBeginRefreshing() {
        textLabel.text = textDic[.refreshing]
        spinner.startAnimating()
        imageView.hidden = true
    }
    func didBeginRefreshing() {
        
    }
}

class RefreshHeaderContainer:UIView{
    // MARK: - Propertys -
    enum RefreshHeaderState {
        case Idle
        case Pulling
        case Refreshing
        case WillRefresh
    }
    var refreshAction:(()->())?
    var attachedScrollView:UIScrollView!
    var originalInset:UIEdgeInsets?
    weak var delegate:RefreshableHeader?
    private var currentResult:RefreshResult = .None
    private var _state:RefreshHeaderState = .Idle
    private var insetTDelta:CGFloat = 0.0
    var state:RefreshHeaderState{
        get{
            return _state
        }
        set{
            guard newValue != _state else{
                return
            }
            let oldValue = _state
            _state =  newValue
            switch newValue {
            case .Idle:
                guard oldValue == .Refreshing else{
                    return
                }
                UIView.animateWithDuration(0.4, animations: {
                    var oldInset = self.attachedScrollView.contentInset
                    oldInset.top = oldInset.top + self.insetTDelta
                    self.attachedScrollView.contentInset = oldInset
                    
                    }, completion: { (finished) in
                        self.delegate?.didEndRefreshing(self.currentResult)
                })
            case .Refreshing:
                dispatch_async(dispatch_get_main_queue(), {
                    UIView.animateWithDuration(0.4, animations: {
                        let top = (self.originalInset?.top)! + CGRectGetHeight(self.frame)
                        var oldInset = self.attachedScrollView.contentInset
                        oldInset.top = top
                        self.attachedScrollView.contentInset = oldInset
                        self.attachedScrollView.contentOffset = CGPointMake(0, -1.0 * top)
                        }, completion: { (finsihed) in
                            self.delegate?.didBeginRefreshing()
                            self.refreshAction?()
                    })
                })
            default:
                break
            }
        }
    }
    // MARK: - Init -
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    func commonInit(){
        self.userInteractionEnabled = true
        self.backgroundColor = UIColor.clearColor()
        self.autoresizingMask = .FlexibleWidth
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Life circle -
    override func drawRect(rect: CGRect) {
        super.drawRect(rect)
        if self.state == .WillRefresh {
            self.state = .Refreshing
        }
    }
    override func willMoveToSuperview(newSuperview: UIView?) {
        super.willMoveToSuperview(newSuperview)
        guard newSuperview is UIScrollView else{
            return;
        }
        attachedScrollView = newSuperview as? UIScrollView
        attachedScrollView.alwaysBounceVertical = true
        originalInset = attachedScrollView?.contentInset
        addObservers()
    }
    deinit{
        removeObservers()
    }
    // MARK: - Private -
    private func addObservers(){
        attachedScrollView?.addObserver(self, forKeyPath:PullToRefreshKitConst.KPathOffSet, options: [.Old,.New], context: nil)
    }
    private func removeObservers(){
        attachedScrollView?.removeObserver(self, forKeyPath: PullToRefreshKitConst.KPathOffSet,context: nil)
    }
    func handleScrollOffSetChange(change: [String : AnyObject]?){
        if state == .Refreshing {
//Refre from here https://github.com/CoderMJLee/MJRefresh/blob/master/MJRefresh/Base/MJRefreshHeader.m, thanks to this lib again
            guard self.window != nil else{
                return
            }
            let offset = attachedScrollView.contentOffset
            let inset = originalInset!
            var insetT = -1 * offset.y > inset.top ? (-1 * offset.y):inset.top
            insetT = insetT > CGRectGetHeight(self.frame) + inset.top ? CGRectGetHeight(self.frame) + inset.top:insetT
            var oldInset = attachedScrollView.contentInset
            oldInset.top = insetT
            attachedScrollView.contentInset = oldInset
            insetTDelta = inset.top - insetT
            return;
        }
        originalInset =  attachedScrollView.contentInset
        let offSetY = attachedScrollView.contentOffset.y
        let topShowOffsetY = -1.0 * originalInset!.top
        guard offSetY <= topShowOffsetY else{
            return
        }
        let normal2pullingOffsetY = topShowOffsetY - self.frame.size.height
        let percent = (topShowOffsetY - offSetY)/self.frame.size.height
        if attachedScrollView.dragging {
            if state == .Idle && offSetY < normal2pullingOffsetY {
                self.state = .Pulling
            }else if state == .Pulling && offSetY >= normal2pullingOffsetY{
                state = .Idle
            }
            self.delegate?.percentageChangedDuringDragging(percent)
        }else if state == .Pulling{
            beginRefreshing()
        }
    }
    // MARK: - KVO -
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        guard self.userInteractionEnabled else{
            return;
        }
        if keyPath == PullToRefreshKitConst.KPathOffSet {
            handleScrollOffSetChange(change)
        }
    }
    // MARK: - API -
    func beginRefreshing(){
        self.delegate?.willBeginRefreshing()
        if self.window != nil {
            self.state = .Refreshing
        }else{
            if state != .Refreshing{
                self.state = .WillRefresh
            }
        }
    }
    func endRefreshing(result:RefreshResult){
        self.delegate?.willEndRefreshing(result)
        self.state = .Idle
    }
}


