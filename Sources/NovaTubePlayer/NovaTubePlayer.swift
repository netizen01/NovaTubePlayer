//
//  NovaTubePlayer.swift
//  NovaTubePlayer
//

import UIKit
import WebKit

public enum NovaTubePlayerState: String {
    case unstarted  = "-1"
    case ended      = "0"
    case playing    = "1"
    case paused     = "2"
    case buffering  = "3"
    case queued     = "4"
}

public enum NovaTubePlayerEvents: String {
    case youTubeIframeAPIReady  = "onYouTubeIframeAPIReady"
    case ready                  = "onReady"
    case stateChange            = "onStateChange"
    case playbackQualityChange  = "onPlaybackQualityChange"
    case error                  = "onError"
    case playTime               = "onPlayTime"
}

public enum NovaTubePlaybackQuality: String {
    case small          = "small"
    case medium         = "medium"
    case large          = "large"
    case hd720          = "hd720"
    case hd1080         = "hd1080"
    case highResolution = "highres"
}

public enum NovaTubePlayerError {
    case invalidParameter
    case html5
    case videoNotFound
    case notEmbeddable
}

public protocol NovaTubePlayerDelegate: class {
    func playerReady(_ videoPlayer: NovaTubePlayer)
    func player(_ videoPlayer: NovaTubePlayer, stateChanged state: NovaTubePlayerState)
    func player(_ videoPlayer: NovaTubePlayer, playbackQualityChanged quality: NovaTubePlaybackQuality)
    func player(_ videoPlayer: NovaTubePlayer, receivedError error: NovaTubePlayerError)
    func player(_ videoPlayer: NovaTubePlayer, didPlayTime time: TimeInterval)
    func player(_ videoPlayer: NovaTubePlayer, log: String)
}

// Make delegate methods optional by providing default implementations
public extension NovaTubePlayerDelegate {
    func playerReady(_ videoPlayer: NovaTubePlayer) {}
    func player(_ videoPlayer: NovaTubePlayer, stateChanged state: NovaTubePlayerState) {}
    func player(_ videoPlayer: NovaTubePlayer, playbackQualityChanged quality: NovaTubePlaybackQuality) {}
    func player(_ videoPlayer: NovaTubePlayer, receivedError error: NovaTubePlayerError) {}
    func player(_ videoPlayer: NovaTubePlayer, didPlayTime time: TimeInterval) {}
    func player(_ videoPlayer: NovaTubePlayer, log: String) {}
}



public func videoIDFromYouTubeURL(_ videoURL: URL) -> String? {
    if let host = videoURL.host, videoURL.pathComponents.count > 1 && host.hasSuffix("youtu.be") {
        return videoURL.pathComponents[1]
    }
    return videoURL.queryStringComponents()["v"] as? String
}

/** Embed and control YouTube videos */
open class NovaTubePlayer: UIView {
    
    public typealias NovaTubePlayerParameters = [String: AnyObject]
    
    open private(set) var webView: WKWebView!
    
    /** The readiness of the player */
    open private(set) var ready = false
    
    /** The current state of the video player */
    open private(set) var playerState = NovaTubePlayerState.unstarted
    
    /** The current playback quality of the video player */
    open private(set) var playbackQuality = NovaTubePlaybackQuality.small
    
    /** Used to configure the player */
    open var playerVars = NovaTubePlayerParameters()
    
    /** Used to respond to player events */
    open weak var delegate: NovaTubePlayerDelegate?
    
    
    // MARK: Various methods for initialization
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        buildWebView(playerParameters())
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        buildWebView(playerParameters())
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        // Remove web view in case it's within view hierarchy, reset frame, add as subview
        webView.removeFromSuperview()
        webView.frame = bounds
        addSubview(webView)
    }
    
    
    // MARK: Web view initialization
    
    private func buildWebView(_ parameters: [String: AnyObject]) {
        backgroundColor = .clear
        let webviewConfiguration = WKWebViewConfiguration()
        webviewConfiguration.allowsInlineMediaPlayback = true
        webviewConfiguration.mediaPlaybackRequiresUserAction = false
        
//        webviewConfiguration.preferences.javaScriptCanOpenWindowsAutomatically = true

        
        webView = WKWebView(frame: CGRect.zero, configuration: webviewConfiguration)
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
    }
    
    
    // MARK: Load player
    
    open func loadVideoURL(_ videoURL: URL) {
        if let videoID = videoIDFromYouTubeURL(videoURL) {
            loadVideoID(videoID)
        }
    }
    
    open func loadVideoID(_ videoID: String) {
        var playerParams = playerParameters()
        playerParams["videoId"] = videoID as AnyObject?
        
        loadWebViewWithParameters(playerParams)
    }
    
    open func loadPlaylistID(_ playlistID: String) {
        // No videoId necessary when listType = playlist, list = [playlist Id]
        playerVars["listType"] = "playlist" as AnyObject?
        playerVars["list"] = playlistID as AnyObject?
        
        loadWebViewWithParameters(playerParameters())
    }
    
    
    // MARK: Player controls
    
    open func play() {
        evaluatePlayerCommand("playVideo()")
    }
    
    open func pause() {
        evaluatePlayerCommand("pauseVideo()")
    }
    
    open func stop() {
        evaluatePlayerCommand("stopVideo()")
    }
    
    open func clear() {
        evaluatePlayerCommand("clearVideo()")
    }
    
    open var shuffle: Bool = false {
        didSet {
            evaluatePlayerCommand("setShuffle(\(shuffle ? "true" : "false"))")
        }
    }
    
    open func mute() {
        evaluatePlayerCommand("mute()")
    }
    
    open func unMute() {
        evaluatePlayerCommand("unMute()")
    }
    
    open func seekTo(_ seconds: Float, seekAhead: Bool) {
        evaluatePlayerCommand("seekTo(\(seconds), \(seekAhead))")
    }
    
    open func getDuration() -> TimeInterval? {
        if let duration = evaluatePlayerCommand("getDuration()") {
            return TimeInterval(duration)
        }
        return nil
    }
    
    open func getCurrentTime() -> TimeInterval? {
        if let currentTime = evaluatePlayerCommand("getCurrentTime()") {
            return TimeInterval(currentTime)
        }
        return nil
    }
    
    open func getVideoUrl() -> URL? {
        if let videoUrl = evaluatePlayerCommand("getVideoUrl()") {
            return URL(string: videoUrl)
        }
        return nil
    }
    
    open func getVideoId() -> String? {
        if let videoUrl = getVideoUrl() {
            return videoUrl.queryStringComponents()["v"] as? String
        }
        return nil
    }
    
    open func videoEmbedCode() -> String? {
        return evaluatePlayerCommand("getVideoEmbedCode()")
    }
    
    // MARK: Playlist controls
    
    open func previousVideo() {
        evaluatePlayerCommand("previousVideo()")
    }
    
    open func nextVideo() {
        evaluatePlayerCommand("nextVideo()")
    }
    
    @discardableResult private func evaluatePlayerCommand(_ command: String) -> String? {
        let fullCommand = "player." + command + ";"
        var value = ""
        webView.evaluateJavaScript(fullCommand) { result, error in
            if error == nil {
                value = result as? String ?? ""
            }
        }
        return value
    }
    
    
    // MARK: Player setup
    private func loadWebViewWithParameters(_ parameters: NovaTubePlayerParameters) {
        // Get HTML from player file in bundle
        let rawHTMLString = YouTubeHTML
        // Get JSON serialized parameters string
        let jsonParameters = serializedJSON(parameters as AnyObject)!
        // Replace %@ in rawHTMLString with jsonParameters string
        let htmlString = rawHTMLString.replacingOccurrences(of: "%@", with: jsonParameters)
        let baseURL: URL?
        if  let playerVars = parameters["playerVars"] as? NovaTubePlayerParameters,
            let origin = playerVars["origin"] as? String,
            let originURL = URL(string: origin) {
            baseURL = originURL
        } else {
            baseURL = URL(string: "about:blank")
        }
        // Load HTML in web view
        webView.loadHTMLString(htmlString, baseURL: baseURL)
    }
    
    // MARK: Player parameters and defaults
    
    private func playerParameters() -> NovaTubePlayerParameters {
        return [
            "height": "100%" as AnyObject,
            "width": "100%" as AnyObject,
            "events": playerCallbacks() as AnyObject,
            "playerVars": playerVars as AnyObject
        ]
    }
    
    private func playerCallbacks() -> NovaTubePlayerParameters {
        return [
            "onReady": "onReady" as AnyObject,
            "onStateChange": "onStateChange" as AnyObject,
            "onPlaybackQualityChange": "onPlaybackQualityChange" as AnyObject,
            "onError": "onPlayerError" as AnyObject
        ]
    }
    
    private func serializedJSON(_ object: AnyObject) -> String? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: object, options: JSONSerialization.WritingOptions.prettyPrinted)
            return String(data: jsonData, encoding: .utf8)
        } catch let jsonError {
            delegate?.player(self, log: "Error parsing JSON: \(jsonError.localizedDescription)")
            return nil
        }
    }
    
    
    // MARK: JS Event Handling
    fileprivate func handleJSEvent(_ eventURL: URL) {
        
        // Grab the last component of the queryString as string
        guard let host = eventURL.host else { return }
        guard let event = NovaTubePlayerEvents(rawValue: host) else { return }
        
        let data: String? = eventURL.queryStringComponents()["data"] as? String
        
        // Check event type and handle accordingly
        switch event {
        case .youTubeIframeAPIReady:
            ready = true
            
        case .ready:
            delegate?.playerReady(self)
            
        case .stateChange:
            if let data = data, let newState = NovaTubePlayerState(rawValue: data) {
                playerState = newState
                delegate?.player(self, stateChanged: newState)
            }
            
        case .playbackQualityChange:
            if let data = data, let newQuality = NovaTubePlaybackQuality(rawValue: data) {
                playbackQuality = newQuality
                delegate?.player(self, playbackQualityChanged: newQuality)
            }
            
        case .error:
            if let data = data, let errorCode = NovaTubePlayerErrorCodes(rawValue: data) {
                let error: NovaTubePlayerError
                switch errorCode {
                case .cannotFindVideo:
                    fallthrough
                case .videoNotFound:
                    error = .videoNotFound
                case .html5:
                    error = .html5
                case .invalidParameter:
                    error = .invalidParameter
                case .notEmbeddable:
                    fallthrough
                case .sameAsNotEmbeddable:
                    error = .notEmbeddable
                }
                delegate?.player(self, receivedError: error)
            }
            
        case .playTime:
            if let data = data, let time = TimeInterval(data) {
                delegate?.player(self, didPlayTime: time)
            }
            
        }
    }
    
}

extension NovaTubePlayer: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let url = navigationAction.request.url
        // Check if ytplayer event and, if so, pass to handleJSEvent
        if let url = url, url.scheme == "ytplayer" {
            handleJSEvent(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }
}


private let YouTubeHTML: String = """
<!DOCTYPE html>
<html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
            * { margin: 0; padding: 0; }
            html, body { width: 100%; height: 100%; }
        </style>
    </head>
    <body>
        <div id="player"></div>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
            var player;
            YT.ready(function() {
                player = new YT.Player('player', %@);
                //player.setSize(window.innerWidth, window.innerHeight);
                window.location.href = 'ytplayer://onYouTubeIframeAPIReady';

                // this will transmit playTime frequently while playng
                function getCurrentTime() {
                    var state = player.getPlayerState();
                    if (state == YT.PlayerState.PLAYING) {
                        time = player.getCurrentTime()
                        window.location.href = 'ytplayer://onPlayTime?data=' + time;
                    }
                }
                window.setInterval(getCurrentTime, 500);
            });
            function onReady(event) {
                window.location.href = 'ytplayer://onReady?data=' + event.data;
            }
            function onStateChange(event) {
                window.location.href = 'ytplayer://onStateChange?data=' + event.data;
            }
            function onPlaybackQualityChange(event) {
                window.location.href = 'ytplayer://onPlaybackQualityChange?data=' + event.data;
            }
            function onPlayerError(event) {
                window.location.href = 'ytplayer://onError?data=' + event.data;
            }
        </script>
    </body>
</html>
"""





private enum NovaTubePlayerErrorCodes: String {
    case invalidParameter       = "2"
    case html5                  = "5"
    case videoNotFound          = "100"
    case notEmbeddable          = "101"
    case cannotFindVideo        = "105"
    case sameAsNotEmbeddable    = "150"
}

private extension URL {
    func queryStringComponents() -> [String: AnyObject] {
        
        var dict = [String: AnyObject]()
        
        // Check for query string
        if let query = self.query {
            
            // Loop through pairings (separated by &)
            for pair in query.components(separatedBy: "&") {
                
                // Pull key, val from from pair parts (separated by =) and set dict[key] = value
                let components = pair.components(separatedBy: "=")
                if (components.count > 1) {
                    dict[components[0]] = components[1] as AnyObject?
                }
            }
            
        }
        
        return dict
    }
}
