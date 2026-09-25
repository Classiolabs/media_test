import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:developer' as dev;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class OvenPlayer extends StatefulWidget {
  const OvenPlayer({super.key});

  @override
  State<OvenPlayer> createState() => _OvenPlayerState();
}

class _OvenPlayerState extends State<OvenPlayer> {
  InAppWebViewController? webViewController;
  String hlsJs = '';
  String distplayerJs = '';
  bool isLoading = true;
  bool isButtonsVisible = true;
  int? lastPlaybackPosition;
  double minPlaybackSpeed = 0.5;
  double maxPlaybackSpeed = 2.0;

  final url = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

  void initialize(String qualityUrl, {bool isQualityChange = false}) {
    try {} catch (e) {
      log('Error initializing proxy server: $e');
    }
    if (isQualityChange) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> setOvenPlayerJs() async {
    try {
      if (hlsJs.isEmpty) {
        hlsJs = await rootBundle.loadString('assets/html/hls.min.js');
      }
      if (distplayerJs.isEmpty) {
        distplayerJs = await rootBundle.loadString('assets/html/distplayer.js');
      }
      log('OvenPlayer JS files loaded successfully');
    } catch (e) {
      log('Error loading OvenPlayer JS files: $e');
    }
  }

  void log(String message) {
    dev.log('OvenPlayer: $message');
  }

  void onStart() async {
    log('No media available to play.');
    await setOvenPlayerJs();

    setState(() {
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    PlatformInAppWebViewController.debugLoggingSettings.enabled = false;
    onStart();
  }

  @override
  void dispose() {
    webViewController?.removeJavaScriptHandler(handlerName: 'timeHandler');
    webViewController?.removeJavaScriptHandler(handlerName: 'playHandler');
    webViewController?.dispose();
    webViewController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: InAppWebView(
              initialSettings: InAppWebViewSettings(
                useHybridComposition: false,
                hardwareAcceleration: false,
                clearCache: true,
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                incognito: true,
                allowsInlineMediaPlayback: true,
                supportZoom: false,
              ),
              initialData: InAppWebViewInitialData(data: getHtml()),

              onConsoleMessage: (controller, consoleMessage) {
                log('WebView Console: ${consoleMessage.messageLevel} - ${consoleMessage.message}');
              },
              onLoadStop: (controller, url) {
                webViewController?.evaluateJavascript(source: 'initializeVideo("${Uri.encodeComponent('https://example.com/video.m3u8')}")');
                Future.delayed(const Duration(milliseconds: 500), () {
                  webViewController?.evaluateJavascript(source: 'setMute(false)');
                });
              },
            ),
          );
  }

  String getPlayerName(String name) {
    int index = name.indexOf('(');
    if (index != -1) {
      return name.substring(0, index).trim();
    }
    return name.trim();
  }

  String getHtml() =>
      """
  <!DOCTYPE html>
<html lang="en">

<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>

<style>
  body {
    margin: 0;
    padding: 0;
    overflow: hidden;
    background-color: black;
    font-family: Arial, sans-serif;

  }

  #mainStream {
    width: 100%;
    height: 100vh;
    background-color: black;
    --op-accent-color: orange;
  }

  .setting-holder {
    display: none;
  }

  .fullscreen-holder {
    display: none;
  }

  #video-container {
    height: 100vh;
  }

  /* Custom three-section control layout */
    .op-controls {
      display: flex !important;
      justify-content: space-between !important;
      align-items: center !important;
      padding: 0 20px !important;
    }

    /* Left section: Duration and Volume */
    .op-left-controls {
      position: static !important;
      display: flex !important;
      align-items: center !important;
      gap: 15px;
      padding: 0 !important;
      flex: 1;
      justify-content: flex-start;
    }

    /* Center section: Seek buttons and Play/Pause */
    .op-left-controls .op-play-controller {
      position: absolute !important;
      left: 50% !important;
      transform: translateX(-50%) !important;
      display: flex !important;
      align-items: center !important;
      gap: 5px;
      z-index: 10;
    }

    /* Right section: Settings */
    .op-right-controls {
      position: static !important;
      display: flex !important;
      align-items: center !important;
      padding: 0 !important;
      flex: 1;
      justify-content: flex-end;
    }

    /* Hide unnecessary buttons */
    .op-right-controls .op-navigators:not(.setting-holder) {
      display: none !important;
    }

    /* Ensure time display and volume are visible */
    .op-left-controls .op-time-display,
    .op-left-controls .op-volume-controller {
      position: static !important;
      z-index: 5;
    }

    /* Reorder play controller buttons: seek-back, play, seek-forward */
    .op-play-controller .op-seek-button-back {
      order: 1;
    }

    .op-play-controller .op-play-button {
      order: 2;
    }

    .op-play-controller .op-seek-button-forward {
      order: 3;
    }
</style>

<body>
  <div id="video-container">
    <div id="mainStream"></div>
  </div>
  
  <!-- Load scripts in order -->
  <script src="data:text/javascript;base64,${base64Encode(utf8.encode(hlsJs))}"></script>
  <script src="data:text/javascript;base64,${base64Encode(utf8.encode(distplayerJs))}"></script>
  
  <script>
    var videoPlayer = null;
    var isPlayerInitialized = false;

    // Wait for scripts to load
    window.addEventListener('load', function() {
      console.log('Window loaded, OvenPlayer available:', typeof OvenPlayer !== 'undefined');
    });

    function initializeVideo(videoUrl, isMp4) {
      console.log('Initializing video with URL:', videoUrl, 'isMp4:', isMp4);
      console.log('OvenPlayer available:', typeof OvenPlayer !== 'undefined');
      
      // Check if OvenPlayer is available with retry
      if (typeof OvenPlayer === 'undefined') {
        console.error('OvenPlayer is not defined, retrying in 100ms');
        setTimeout(function() {
          initializeVideo(videoUrl, isMp4);
        }, 100);
        return;
      }

      // Destroy existing player if it exists
      if (videoPlayer && isPlayerInitialized) {
        try {
          console.log('Removing existing player');
          if (typeof videoPlayer.remove === 'function') {
            videoPlayer.remove();
          } else if (typeof videoPlayer.destroy === 'function') {
            videoPlayer.destroy();
          }
        } catch (e) {
          console.log('Error removing existing player:', e);
        }
        videoPlayer = null;
        isPlayerInitialized = false;
      }

      // Clear the container
      const container = document.getElementById('mainStream');
      if (container) {
        container.innerHTML = '';
      }

      try {
        // Create new player
        console.log('Creating new OvenPlayer');
        videoPlayer = OvenPlayer.create('mainStream', {
          sources: [
            {
              label: '4k',
              type: isMp4 ? 'mp4' : 'hls',
              file: videoUrl,
            },
          ],
          "parseStream": {
            "enabled": true
          },
          hlsConfig: {
            xhrSetup: function (xhr, url) {
              xhr.setRequestHeader('Authorization', `Bearer sdf23434`); // Replace with actual token if needed
            },
            fetchSetup: function (context, initParams) {
              initParams.headers = {
                ...initParams.headers,
                'Authorization': `Bearer sdf23434`, // Replace with actual token if needed
              };
              return new Request(context.url, initParams);
            },
          },
          mute: false,
          autoStart: false,
          showBigPlayButton: false,
          expandFullScreenUI: false,
          doubleTapToSeek: true,
          showSeekControl: true,
        });

        // Seek to desired position (in seconds)
        videoPlayer.on('ready', function() {
          console.log('Player ready, seeking to last position : ${lastPlaybackPosition != null ? lastPlaybackPosition! ~/ 1000 : 0} seconds');
          videoPlayer.seek(${lastPlaybackPosition != null ? lastPlaybackPosition! ~/ 1000 : 0});
          videoPlayer.play();
        });

        if (videoPlayer) {
          console.log('Player created successfully');
          isPlayerInitialized = true;
          videoPlayer.showControls(true);
          videoPlayer.on('time', function(data) {
            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
              window.flutter_inappwebview.callHandler('timeHandler', data.position, data.duration);
            }
          });
          videoPlayer.on('stateChanged', function(data) {
            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
              window.flutter_inappwebview.callHandler('playHandler', data.newstate);
            }
          });
        } else {
          console.error('Failed to create video player');
        }
      } catch (e) {
        console.error('Error creating video player:', e);
      }
    }

    function getState() {
      if (!videoPlayer || !isPlayerInitialized) {
        console.log('Player not initialized for getState');
        return;
      }
      try {
        const playingEvent = new CustomEvent('state', {
          detail: {
            status: videoPlayer.getState(),
          }
        });
        window.dispatchEvent(playingEvent);
      } catch (e) {
        console.error('Error in getState:', e);
      }
    }

    function setVolume(volume) {
      if (!videoPlayer || !isPlayerInitialized) {
        console.log('Player not initialized for setVolume');
        return;
      }
      try {
        videoPlayer.setVolume(volume);
      } catch (e) {
        console.error('Error in setVolume:', e);
      }
    }

    function setPlaybackRate(rate) {
      if (!videoPlayer || !isPlayerInitialized) {
        console.log('Player not initialized for setPlaybackRate');
        return;
      }
      try {
        videoPlayer.setPlaybackRate(rate);
      } catch (e) {
        console.error('Error in setPlaybackRate:', e);
      }
    }

    function play() {
      if (!videoPlayer || !isPlayerInitialized) {
        console.log('Player not initialized for play');
        return;
      }
      try {
        videoPlayer.play();
      } catch (e) {
        console.error('Error in play:', e);
      }
    }
    
    function pause() {
      if (!videoPlayer || !isPlayerInitialized) {
        console.log('Player not initialized for pause');
        return;
      }
      try {
        videoPlayer.pause();
      } catch (e) {
        console.error('Error in pause:', e);
      }
    }

    function seekTo(position) {
      if (!videoPlayer || !isPlayerInitialized) {
        console.log('Player not initialized for seekTo');
        return;
      }
      try {
        videoPlayer.seek(position);
      } catch (e) {
        console.error('Error in seekTo:', e);
      }
    }

    function setMute(mute) {
      if (!videoPlayer || !isPlayerInitialized) {
        console.log('Player not initialized for setMute');
        return;
      }
      try {
        videoPlayer.setMute(mute);
      } catch (e) {
        console.error('Error in setMute:', e);
      }
    }
  </script>
</body>
</html>
""";

  String getNewHtml() =>
      """
 <!DOCTYPE html>
<html lang="en">

<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>

<style>
  * {
    box-sizing: border-box;
    -webkit-tap-highlight-color: transparent;
  }
  
  body {
    margin: 0;
    padding: 0;
    overflow: hidden;
    background: linear-gradient(135deg, #0a0a0a 0%, #1a1a1a 100%);
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
    user-select: none;
    -webkit-user-select: none;
  }
  
  #video-container {
    height: 100vh;
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  #native-video {
    width: 100%;
    height: 100vh;
    background: #000;
    object-fit: contain;
  }
  
  .custom-controls {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    background: linear-gradient(to top, 
      rgba(0,0,0,0.9) 0%, 
      rgba(0,0,0,0.7) 40%, 
      rgba(0,0,0,0.3) 70%, 
      transparent 100%);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    padding: 10px 50px 0px 50px;
    z-index: 1000;
    transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
    transform: translateY(0);
  }
  
  .custom-controls.hidden {
    opacity: 0;
    transform: translateY(20px);
    pointer-events: none;
  }
  
  .progress-section {
    margin-bottom: 24px;
  }
  
  .progress-container {
    position: relative;
    height: 6px;
    background: rgba(255,255,255,0.15);
    border-radius: 3px;
    margin-bottom: 5px;
    overflow: hidden;
  }
  
  .progress-bar {
    position: absolute;
    top: 0;
    left: 0;
    height: 100%;
    background: linear-gradient(90deg, #ff6b35 0%, #ff8c42 100%);
    border-radius: 3px;
    width: 0%;
    transition: width 0.1s ease;
  }
  
  .progress-handle {
    position: absolute;
    top: 50%;
    left: 0%;
    width: 18px;
    height: 18px;
    background: #fff;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    box-shadow: 0 2px 12px rgba(0,0,0,0.3);
    cursor: pointer;
    opacity: 0;
    transition: opacity 0.3s ease, transform 0.2s ease;
  }
  
  .progress-container:hover .progress-handle,
  .progress-container.dragging .progress-handle {
    opacity: 1;
    transform: translate(-50%, -50%) scale(1.2);
  }
  
  .time-display {
    display: flex;
    justify-content: space-between;
    align-items: center;
    color: rgba(255,255,255,0.9);
    font-size: 13px;
    font-weight: 500;
    letter-spacing: 0.5px;
    margin-bottom: 5px;
  }
  
  .time-current {
    color: #ff6b35;
  }
  
  .bottom-controls {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  
  .mute-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 40px;
    height: 40px;
    background: rgba(0,0,0,0.6);
    border: 1px solid rgba(255,255,255,0.2);
    color: rgba(255,255,255,0.9);
    border-radius: 20px;
    font-size: 16px;
    cursor: pointer;
    transition: all 0.3s ease;
    backdrop-filter: blur(10px);
    -webkit-backdrop-filter: blur(10px);
  }
  
  .mute-btn:hover {
    background: rgba(255,107,53,0.2);
    border-color: rgba(255,107,53,0.4);
    transform: scale(1.05);
  }
  
  .mute-btn:active {
    transform: scale(0.95);
  }
  
  .mute-btn.muted {
    background: rgba(255,107,53,0.3);
    border-color: rgba(255,107,53,0.5);
    color: #ff6b35;
  }
  
  .control-buttons {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 20px;
    z-index: 1500;
    opacity: 0;
    transition: opacity 0.4s cubic-bezier(0.4, 0, 0.2, 1);
    pointer-events: none;
  }
  
  .control-buttons.visible {
    opacity: 1;
    pointer-events: all;
  }
  
  .control-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 56px;
    height: 56px;
    background: rgba(0,0,0,0.7);
    border: 2px solid rgba(255,255,255,0.2);
    color: rgba(255,255,255,0.95);
    border-radius: 28px;
    font-size: 18px;
    cursor: pointer;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    position: relative;
    overflow: hidden;
    box-shadow: 0 4px 20px rgba(0,0,0,0.3);
  }
  
  .control-btn::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: linear-gradient(135deg, rgba(255,107,53,0.1) 0%, rgba(255,140,66,0.1) 100%);
    opacity: 0;
    transition: opacity 0.3s ease;
  }
  
  .control-btn:active {
    transform: scale(0.95);
  }
  
  .control-btn:hover::before {
    opacity: 1;
  }
  
  .play-pause-btn {
    width: 80px;
    height: 80px;
    border-radius: 40px;
    background: rgba(0,0,0,0.8);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border: 2px solid rgba(255,255,255,0.3);
    color: white;
    font-size: 32px;
    box-shadow: 0 6px 25px rgba(0,0,0,0.5);
    margin: 0 12px;
  }
  
  .play-pause-btn:hover {
    box-shadow: 0 8px 30px rgba(255,107,53,0.5);
    transform: translateY(-2px) scale(1.05);
  }
  
  .play-pause-btn:active {
    transform: translateY(-2px) scale(0.98);
  }
  
  .seek-text {
    font-size: 11px;
    font-weight: 600;
    opacity: 0.8;
  }
  
  .loading-spinner {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    z-index: 2000;
    opacity: 1;
    transition: opacity 0.4s ease;
  }
  
  .loading-spinner.hidden {
    opacity: 0;
    pointer-events: none;
  }
  
  .spinner {
    width: 50px;
    height: 50px;
    border: 3px solid rgba(255,255,255,0.1);
    border-top: 3px solid #ff6b35;
    border-radius: 50%;
    animation: spin 1.2s cubic-bezier(0.4, 0, 0.2, 1) infinite;
    filter: drop-shadow(0 0 10px rgba(255,107,53,0.3));
  }
  
  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
  
  .tap-indicator {
    position: absolute;
    width: 80px;
    height: 80px;
    border: 2px solid rgba(255,255,255,0.6);
    border-radius: 50%;
    pointer-events: none;
    opacity: 0;
    transform: scale(0.8);
    animation: tapRipple 0.6s ease-out;
  }
  
  @keyframes tapRipple {
    0% {
      opacity: 0.8;
      transform: scale(0.8);
    }
    100% {
      opacity: 0;
      transform: scale(2);
    }
  }
  
  /* Modern scrollbar for any overflow */
  ::-webkit-scrollbar {
    width: 4px;
  }
  
  ::-webkit-scrollbar-track {
    background: transparent;
  }
  
  ::-webkit-scrollbar-thumb {
    background: rgba(255,107,53,0.3);
    border-radius: 2px;
  }
  
  /* Responsive adjustments */
  @media (max-width: 768px) {
    .custom-controls {
      padding: 25px 16px 35px;
    }
    
    .control-btn {
      width: 52px;
      height: 52px;
      font-size: 16px;
    }
    
    .play-pause-btn {
      width: 72px;
      height: 72px;
      font-size: 28px;
    }
    
    .control-buttons {
      gap: 16px;
    }
  }
</style>

<body>
  <div id="video-container">
    <video id="native-video" 
           playsinline 
           webkit-playsinline 
           muted 
           autoplay
           disablePictureInPicture
           controlsList="nodownload nofullscreen noremoteplayback noplaybackrate">
    </video>
    
    <div class="loading-spinner" id="loading-spinner">
      <div class="spinner"></div>
    </div>
    
    <div class="custom-controls" id="custom-controls">
      <div class="progress-section">
        <div class="progress-container" id="progress-container">
          <div class="progress-bar" id="progress-bar"></div>
          <div class="progress-handle" id="progress-handle"></div>
        </div>
        
        <div class="time-display">
          <span class="time-current" id="time-current">00:00</span>
          <span class="time-total" id="time-total">00:00</span>
        </div>
        
        <div class="bottom-controls">
          <button class="mute-btn" id="mute-btn" title="Mute/Unmute">🔊</button>
        </div>
      </div>
    </div>
    
    <div class="control-buttons" id="control-buttons">
      <button class="control-btn" id="seek-back-btn">
        <div class="seek-text">-10</div>
      </button>
      <button class="control-btn play-pause-btn" id="play-pause-btn">
        <svg width="40" height="40" viewBox="0 0 40 40" fill="none">
          <circle cx="20" cy="20" r="19" fill="rgba(255,255,255,0.08)" stroke="#ff6b35" stroke-width="2"/>
          <polygon id="play-icon" points="15,12 30,20 15,28" fill="#ff6b35"/>
        </svg>
      </button>
      <button class="control-btn" id="seek-forward-btn">
        <div class="seek-text">+10</div>
      </button>
    </div>
  </div>

  <script src="data:text/javascript;base64,${base64Encode(utf8.encode(hlsJs))}"></script>
  <script>
    var videoElement = null;
    var isVideoInitialized = false;
    var controlsTimeout = null;
    var customControls = null;
    var loadingSpinner = null;
    var controlButtons = null;

    window.addEventListener('load', function() {
      videoElement = document.getElementById('native-video');
      customControls = document.getElementById('custom-controls');
      loadingSpinner = document.getElementById('loading-spinner');
      controlButtons = document.getElementById('control-buttons');
      console.log('Android HTML loaded, native video ready');
      
      // Log browser capabilities
      console.log('Video element capabilities:');
      console.log('Can play MP4:', videoElement.canPlayType('video/mp4'));
      console.log('Can play WebM:', videoElement.canPlayType('video/webm'));
      console.log('Can play OGG:', videoElement.canPlayType('video/ogg'));
      console.log('Can play HLS:', videoElement.canPlayType('application/x-mpegURL'));
      
      setupVideoControls();
      setupLoadingIndicator();
    });

    function setupVideoControls() {
      var progressContainer = document.getElementById('progress-container');
      var progressBar = document.getElementById('progress-bar');
      var progressHandle = document.getElementById('progress-handle');
      var timeCurrent = document.getElementById('time-current');
      var timeTotal = document.getElementById('time-total');
      var playPauseBtn = document.getElementById('play-pause-btn');
      var seekBackBtn = document.getElementById('seek-back-btn');
      var seekForwardBtn = document.getElementById('seek-forward-btn');
      var muteBtn = document.getElementById('mute-btn');

      var isDragging = false;
      var tapCount = 0;
      var tapTimer = null;

      // Format time helper with hours support
      function formatTime(sec) {
        if (isNaN(sec)) return '00:00';
        sec = Math.floor(sec);
        
        var h = Math.floor(sec / 3600);
        var m = Math.floor((sec % 3600) / 60);
        var s = sec % 60;
        
        if (h > 0) {
          return (h < 10 ? '0' : '') + h + ':' + 
                 (m < 10 ? '0' : '') + m + ':' + 
                 (s < 10 ? '0' : '') + s;
        } else {
          return (m < 10 ? '0' : '') + m + ':' + 
                 (s < 10 ? '0' : '') + s;
        }
      }

      // Update progress and time display
      videoElement.addEventListener('timeupdate', function() {
        if (!isDragging && videoElement.duration && !isNaN(videoElement.duration)) {
          var percent = (videoElement.currentTime / videoElement.duration) * 100;
          progressBar.style.width = percent + '%';
          progressHandle.style.left = percent + '%';
          timeCurrent.textContent = formatTime(videoElement.currentTime);
          timeTotal.textContent = formatTime(videoElement.duration);
        }
        
        // Send time updates to Flutter - handle null duration
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          var currentTime = videoElement.currentTime || 0;
          var duration = videoElement.duration && !isNaN(videoElement.duration) ? videoElement.duration : 0;
          window.flutter_inappwebview.callHandler('timeHandler', currentTime, duration);
        }
      });

      // Progress bar interaction
      function updateProgressFromEvent(e) {
        var rect = progressContainer.getBoundingClientRect();
        var percent = Math.max(0, Math.min(100, ((e.clientX - rect.left) / rect.width) * 100));
        
        if (videoElement.duration) {
          var newTime = (percent / 100) * videoElement.duration;
          videoElement.currentTime = newTime;
          progressBar.style.width = percent + '%';
          progressHandle.style.left = percent + '%';
          timeCurrent.textContent = formatTime(newTime);
        }
      }

      // Touch/Mouse events for progress bar
      progressContainer.addEventListener('mousedown', function(e) {
        isDragging = true;
        progressContainer.classList.add('dragging');
        updateProgressFromEvent(e);
        showControlsTemporarily();
      });

      progressContainer.addEventListener('touchstart', function(e) {
        e.preventDefault();
        isDragging = true;
        progressContainer.classList.add('dragging');
        updateProgressFromEvent(e.touches[0]);
        showControlsTemporarily();
      });

      document.addEventListener('mousemove', function(e) {
        if (isDragging) {
          updateProgressFromEvent(e);
        }
      });

      document.addEventListener('touchmove', function(e) {
        if (isDragging) {
          e.preventDefault();
          updateProgressFromEvent(e.touches[0]);
        }
      });

      document.addEventListener('mouseup', function() {
        if (isDragging) {
          isDragging = false;
          progressContainer.classList.remove('dragging');
        }
      });

      document.addEventListener('touchend', function() {
        if (isDragging) {
          isDragging = false;
          progressContainer.classList.remove('dragging');
        }
      });

      // Play/pause state updates
      videoElement.addEventListener('play', function() {
        playPauseBtn.innerHTML = `
          <svg width="40" height="40" viewBox="0 0 40 40" fill="none">
            <circle cx="20" cy="20" r="19" fill="rgba(255,255,255,0.08)" stroke="#ff6b35" stroke-width="2"/>
            <polygon id="pause-icon" points="16,12 16,28 19,28 19,12 21,12 21,28 24,28 24,12" fill="#ff6b35"/>
          </svg>
        `;
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('playHandler', 'playing');
        }
      });

      videoElement.addEventListener('pause', function() {
        playPauseBtn.innerHTML = `
          <svg width="40" height="40" viewBox="0 0 40 40" fill="none">
            <circle cx="20" cy="20" r="19" fill="rgba(255,255,255,0.08)" stroke="#ff6b35" stroke-width="2"/>
            <polygon id="play-icon" points="15,12 30,20 15,28" fill="#ff6b35"/>
          </svg>
        `;
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('playHandler', 'paused');
        }
      });

      // Volume/mute state updates
      videoElement.addEventListener('volumechange', function() {
        updateMuteButton();
      });

      function updateMuteButton() {
        if (muteBtn) {
          if (videoElement.muted || videoElement.volume === 0) {
            muteBtn.innerHTML = '🔇';
            muteBtn.classList.add('muted');
            muteBtn.title = 'Unmute';
          } else {
            muteBtn.innerHTML = '🔊';
            muteBtn.classList.remove('muted');
            muteBtn.title = 'Mute';
          }
        }
      }

      // Control button events with haptic-like feedback
      function createTapIndicator(element) {
        var indicator = document.createElement('div');
        indicator.className = 'tap-indicator';
        var rect = element.getBoundingClientRect();
        indicator.style.left = (rect.left + rect.width/2 - 40) + 'px';
        indicator.style.top = (rect.top + rect.height/2 - 40) + 'px';
        document.body.appendChild(indicator);
        
        setTimeout(function() {
          document.body.removeChild(indicator);
        }, 600);
      }

      playPauseBtn.addEventListener('click', function() {
        // Don't allow control if loading
        if (loadingSpinner && loadingSpinner.classList.contains('show')) {
          return;
        }
        
        createTapIndicator(this);
        if (videoElement.paused) {
          videoElement.play();
        } else {
          videoElement.pause();
        }
        showControlsTemporarily();
      });

      seekBackBtn.addEventListener('click', function() {
        // Don't allow control if loading
        if (loadingSpinner && loadingSpinner.classList.contains('show')) {
          return;
        }
        
        createTapIndicator(this);
        videoElement.currentTime = Math.max(0, videoElement.currentTime - 10);
        showControlsTemporarily();
      });

      seekForwardBtn.addEventListener('click', function() {
        // Don't allow control if loading
        if (loadingSpinner && loadingSpinner.classList.contains('show')) {
          return;
        }
        
        createTapIndicator(this);
        videoElement.currentTime = Math.min(videoElement.duration, videoElement.currentTime + 10);
        showControlsTemporarily();
      });

      // Mute button event
      muteBtn.addEventListener('click', function() {
        // Don't allow control if loading
        if (loadingSpinner && loadingSpinner.classList.contains('show')) {
          return;
        }
        
        createTapIndicator(this);
        videoElement.muted = !videoElement.muted;
        updateMuteButton();
        showControlsTemporarily();
        
        // Notify Flutter about mute state change
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('muteHandler', videoElement.muted);
        }
      });

      // Single tap to show controls, double tap to play/pause
      videoElement.addEventListener('click', function(e) {
        e.preventDefault();
        
        // Always show controls on any tap, regardless of loading state
        var controlsWereHidden = customControls.classList.contains('hidden');
        showControlsTemporarily();
        
        // Don't allow double tap control if loading
        if (loadingSpinner && loadingSpinner.classList.contains('show')) {
          return;
        }
        
        tapCount++;
        if (tapCount === 1) {
          tapTimer = setTimeout(function() {
            tapCount = 0;
            // If controls were hidden and this was just a single tap, don't do anything else
            // The controls are already shown by showControlsTemporarily() above
          }, 300);
        } else if (tapCount === 2) {
          clearTimeout(tapTimer);
          tapCount = 0;
          
          // Create tap indicator at touch point
          var indicator = document.createElement('div');
          indicator.className = 'tap-indicator';
          indicator.style.left = (e.clientX - 40) + 'px';
          indicator.style.top = (e.clientY - 40) + 'px';
          document.body.appendChild(indicator);
          
          setTimeout(function() {
            document.body.removeChild(indicator);
          }, 600);
          
          // Only toggle play/pause on double tap if controls weren't hidden
          if (!controlsWereHidden) {
            if (videoElement.paused) {
              videoElement.play();
            } else {
              videoElement.pause();
            }
          }
        }
      });

      // Auto-hide controls with smooth transitions
      function showControlsTemporarily() {
        console.log('Showing controls temporarily');
        customControls.classList.remove('hidden');
        // Only show control buttons if not loading
        if (loadingSpinner && !loadingSpinner.classList.contains('show')) {
          controlButtons.classList.add('visible');
        }
        clearTimeout(controlsTimeout);
        controlsTimeout = setTimeout(function() {
          if (!videoElement.paused && !isDragging) {
            console.log('Auto-hiding controls');
            customControls.classList.add('hidden');
            controlButtons.classList.remove('visible');
          }
        }, 4000);
      }

      // Show controls when paused
      videoElement.addEventListener('pause', function() {
        console.log('Video paused, showing controls');
        customControls.classList.remove('hidden');
        // Only show control buttons if not loading
        if (loadingSpinner && !loadingSpinner.classList.contains('show')) {
          controlButtons.classList.add('visible');
        }
        clearTimeout(controlsTimeout);
      });

      // Hide controls when playing (after delay)
      videoElement.addEventListener('play', function() {
        console.log('Video playing, showing controls temporarily');
        showControlsTemporarily();
      });

      // Force show controls on any touch/mouse interaction with the video container
      var videoContainer = document.getElementById('video-container');
      if (videoContainer) {
        videoContainer.addEventListener('touchstart', function(e) {
          // Only handle if the touch is directly on the video area (not on controls)
          if (e.target === videoElement || e.target === videoContainer) {
            console.log('Touch detected on video area');
            showControlsTemporarily();
          }
        });
        
        videoContainer.addEventListener('mousedown', function(e) {
          // Only handle if the click is directly on the video area (not on controls)
          if (e.target === videoElement || e.target === videoContainer) {
            console.log('Mouse click detected on video area');
            showControlsTemporarily();
          }
        });
      }

      console.log('Android video controls setup complete');
      
      // Fallback: Ensure controls can always be shown with a global touch handler
      document.addEventListener('touchend', function(e) {
        // If controls have been hidden for more than 1 second and user taps anywhere, show them
        if (customControls.classList.contains('hidden')) {
          var now = Date.now();
          if (!window.lastControlsHidden || (now - window.lastControlsHidden) > 1000) {
            console.log('Fallback: Showing controls on touch');
            showControlsTemporarily();
          }
        }
      });
      
      // Track when controls get hidden
      var originalClassListAdd = customControls.classList.add;
      customControls.classList.add = function(className) {
        if (className === 'hidden') {
          window.lastControlsHidden = Date.now();
          console.log('Controls hidden at:', window.lastControlsHidden);
        }
        return originalClassListAdd.call(this, className);
      };
    }

    function setupLoadingIndicator() {
      var isInitialLoad = true;
      var seekingTimeout = null;
      
      // Show spinner when loading starts (only for initial load)
      videoElement.addEventListener('loadstart', function() {
        console.log('Video loading started');
        if (isInitialLoad) {
          showLoadingSpinner();
        }
      });

      videoElement.addEventListener('waiting', function() {
        console.log('Video buffering');
        // Only show spinner if we're actually waiting for data and not just paused
        if (!videoElement.paused && videoElement.readyState < 3) {
          showLoadingSpinner();
        }
      });

      videoElement.addEventListener('seeking', function() {
        console.log('Video seeking');
        // Clear any existing timeout
        if (seekingTimeout) {
          clearTimeout(seekingTimeout);
        }
        // Only show spinner for longer seeks (more than 200ms)
        seekingTimeout = setTimeout(function() {
          if (videoElement.seeking) {
            showLoadingSpinner();
          }
        }, 200);
      });

      // Hide spinner when ready to play or playing
      videoElement.addEventListener('canplay', function() {
        console.log('Video can play');
        isInitialLoad = false;
        hideLoadingSpinner();
      });

      videoElement.addEventListener('canplaythrough', function() {
        console.log('Video can play through');
        isInitialLoad = false;
        hideLoadingSpinner();
      });

      videoElement.addEventListener('playing', function() {
        console.log('Video playing');
        isInitialLoad = false;
        hideLoadingSpinner();
      });

      videoElement.addEventListener('seeked', function() {
        console.log('Video seeked');
        // Clear seeking timeout
        if (seekingTimeout) {
          clearTimeout(seekingTimeout);
          seekingTimeout = null;
        }
        hideLoadingSpinner();
      });

      // Enhanced error handling
      videoElement.addEventListener('error', function(e) {
        console.error('Video error occurred:', e);
        hideLoadingSpinner();
        
        // Get more detailed error information
        if (videoElement.error) {
          var errorCode = videoElement.error.code;
          var errorMessage = '';
          
          switch(errorCode) {
            case 1:
              errorMessage = 'MEDIA_ERR_ABORTED - The video playback was aborted';
              break;
            case 2:
              errorMessage = 'MEDIA_ERR_NETWORK - A network error occurred';
              break;
            case 3:
              errorMessage = 'MEDIA_ERR_DECODE - The video is corrupted or unsupported format';
              break;
            case 4:
              errorMessage = 'MEDIA_ERR_SRC_NOT_SUPPORTED - The video source is not supported';
              break;
            default:
              errorMessage = 'Unknown error occurred';
          }
          
          console.error('Detailed video error:', errorMessage, 'Code:', errorCode);
        }
      });

      // Handle empty or invalid sources
      videoElement.addEventListener('emptied', function() {
        console.log('Video source emptied');
        // Only show spinner if we're actually loading a new source
        if (videoElement.src || videoElement.children.length > 0) {
          showLoadingSpinner();
        }
      });

      // Handle stalled loading
      videoElement.addEventListener('stalled', function() {
        console.log('Video loading stalled');
        // Only show spinner if we're actually trying to load and not just paused
        if (!videoElement.paused && videoElement.readyState < 3) {
          showLoadingSpinner();
        }
      });

      // Handle when video source is invalid
      videoElement.addEventListener('loadstart', function() {
        // Check if source is actually valid
        setTimeout(function() {
          if (videoElement.networkState === HTMLMediaElement.NETWORK_NO_SOURCE) {
            console.error('No valid video source detected');
            hideLoadingSpinner();
          }
        }, 100);
      });

      // Handle pause - hide loading spinner when paused
      videoElement.addEventListener('pause', function() {
        // Don't show loading spinner when just paused
        hideLoadingSpinner();
      });

      // Handle progress events to hide spinner when buffering is sufficient
      videoElement.addEventListener('progress', function() {
        if (videoElement.buffered.length > 0) {
          var bufferedEnd = videoElement.buffered.end(videoElement.buffered.length - 1);
          var currentTime = videoElement.currentTime;
          // If we have at least 5 seconds buffered ahead, hide spinner
          if (bufferedEnd - currentTime > 5) {
            hideLoadingSpinner();
          }
        }
      });
    }

    function showLoadingSpinner() {
      if (loadingSpinner && !loadingSpinner.classList.contains('show')) {
        console.log('Showing loading spinner');
        loadingSpinner.classList.remove('hidden');
        loadingSpinner.classList.add('show');
      }
      // Hide control buttons during loading
      if (controlButtons) {
        controlButtons.classList.remove('visible');
      }
    }

    function hideLoadingSpinner() {
      if (loadingSpinner && loadingSpinner.classList.contains('show')) {
        console.log('Hiding loading spinner');
        loadingSpinner.classList.add('hidden');
        loadingSpinner.classList.remove('show');
      }
      // Show control buttons when loading is complete (if controls are visible)
      if (controlButtons && !customControls.classList.contains('hidden')) {
        controlButtons.classList.add('visible');
      }
    }

    // Global functions for Flutter communication
    function initializeVideo(videoUrl, isMp4) {
      console.log('Initializing Android video with URL:', videoUrl, 'isMp4:', isMp4);
      
      if (!videoElement) {
        console.error('Video element not found');
        return;
      }

      // Validate video URL
      if (!videoUrl || videoUrl.trim() === '') {
        console.error('Invalid or empty video URL provided');
        hideLoadingSpinner();
        return;
      }

      try {
        showLoadingSpinner(); // Show spinner when initializing
        
        // Clear any existing source first
        videoElement.removeAttribute('src');
        videoElement.innerHTML = ''; // Clear any source elements
        
        // Reset loading state
        isVideoInitialized = false;

        // Enhanced error handling for source loading
        videoElement.addEventListener('error', function(e) {
          console.error('Video source error:', e);
          if (videoElement.error) {
            console.error('Error code:', videoElement.error.code, 'Message:', videoElement.error.message);
          }
          hideLoadingSpinner();
        });

        // Determine if this is an HLS stream
        var isHls = !isMp4 && videoUrl.toLowerCase().includes('.m3u8');

        if (isHls && typeof Hls !== 'undefined' && Hls.isSupported()) {
          // Use HLS.js with Authorization headers for HLS streams
          console.log('Using HLS.js with Authorization headers');
          var hls = new Hls({
            xhrSetup: function(xhr, url) {
              xhr.setRequestHeader('Authorization', 'Bearer sdf23434'); // Replace with actual token if needed
            },
            fetchSetup: function(context, initParams) {
              initParams.headers = {
                ...initParams.headers,
                'Authorization': 'Bearer sdf23434' // Replace with actual token if needed
              };
              return new Request(context.url, initParams);
            },
          });
          hls.loadSource(videoUrl);
          hls.attachMedia(videoElement);
          hls.on(Hls.Events.MANIFEST_PARSED, function() {
            console.log('HLS manifest parsed, starting playback');
            hideLoadingSpinner();
          });
          hls.on(Hls.Events.ERROR, function(event, data) {
            if (data.fatal) {
              console.error('Fatal HLS error:', data);
              hideLoadingSpinner();
            }
          });
        } else {
          // Native video or non-HLS fallback
          console.log('Using native video element');

          // Create source element for better format support
          var sourceElement = document.createElement('source');
          sourceElement.src = videoUrl;

          // Set appropriate type based on URL or isMp4 parameter
          if (isMp4 || videoUrl.toLowerCase().includes('.mp4')) {
            sourceElement.type = 'video/mp4';
          } else if (videoUrl.toLowerCase().includes('.webm')) {
            sourceElement.type = 'video/webm';
          } else if (videoUrl.toLowerCase().includes('.m3u8')) {
            sourceElement.type = 'application/x-mpegURL';
          } else {
            // Try to determine from URL extension or default to mp4
            var extension = videoUrl.split('.').pop().toLowerCase();
            switch(extension) {
              case 'webm':
                sourceElement.type = 'video/webm';
                break;
              case 'ogg':
                sourceElement.type = 'video/ogg';
                break;
              default:
                sourceElement.type = 'video/mp4';
            }
          }

          console.log('Setting video source:', videoUrl, 'with type:', sourceElement.type);
          videoElement.appendChild(sourceElement);

          // Add error handling for load attempts
          var loadTimeout = setTimeout(function() {
            console.error('Video load timeout - no response after 10 seconds');
            hideLoadingSpinner();
          }, 10000);

          var clearTimeoutHandler = function() {
            clearTimeout(loadTimeout);
            videoElement.removeEventListener('loadstart', clearTimeoutHandler);
          };
          videoElement.addEventListener('loadstart', clearTimeoutHandler);

          videoElement.load(); // Explicitly trigger load
        }

        isVideoInitialized = true;
        console.log('Video initialized successfully');
        
        // Initial state
        var playPauseBtn = document.getElementById('play-pause-btn');
        if (playPauseBtn) {
          playPauseBtn.innerHTML = '▶️'; // Always start with play button
        }
        
        // Initialize mute button state
        updateMuteButton();
        
        // Set a fallback timeout to hide spinner if video doesn't load properly
        setTimeout(function() {
          if (videoElement.readyState === 0) {
            console.warn('Video failed to load after 15 seconds, hiding spinner');
            hideLoadingSpinner();
          }
        }, 15000);
      } catch (e) {
        console.error('Error initializing Android video:', e);
        hideLoadingSpinner(); // Hide spinner on error
      }
    }

    function getState() {
      if (!videoElement || !isVideoInitialized) {
        console.log('Video not initialized for getState');
        return;
      }
      try {
        var state = videoElement.paused ? 'paused' : 'playing';
        var stateEvent = new CustomEvent('state', {
          detail: {
            status: state,
          }
        });
        window.dispatchEvent(stateEvent);
      } catch (e) {
        console.error('Error in getState:', e);
      }
    }

    function setVolume(volume) {
      if (!videoElement || !isVideoInitialized) {
        console.log('Video not initialized for setVolume');
        return;
      }
      try {
        videoElement.volume = Math.max(0, Math.min(1, volume));
      } catch (e) {
        console.error('Error in setVolume:', e);
      }
    }

    function setPlaybackRate(rate) {
      if (!videoElement || !isVideoInitialized) {
        console.log('Video not initialized for setPlaybackRate');
        return;
      }
      try {
        videoElement.playbackRate = rate;
      } catch (e) {
        console.error('Error in setPlaybackRate:', e);
      }
    }

    function play() {
      if (!videoElement || !isVideoInitialized) {
        console.log('Video not initialized for play');
        return;
      }
      try {
        // Check if video has a valid source
        if (!videoElement.src && videoElement.children.length === 0) {
          console.error('Cannot play: No video source set');
          return;
        }
        
        // Check if video has loaded enough data
        if (videoElement.readyState < 2) {
          console.log('Video not ready, waiting for metadata...');
          videoElement.addEventListener('loadedmetadata', function() {
            console.log('Metadata loaded, attempting play...');
            var playPromise = videoElement.play();
            if (playPromise !== undefined) {
              playPromise.catch(function(error) {
                console.error('Play failed after metadata load:', error);
                hideLoadingSpinner();
              });
            }
          }, { once: true });
          return;
        }
        
        var playPromise = videoElement.play();
        if (playPromise !== undefined) {
          playPromise.then(function() {
            console.log('Video play started successfully');
          }).catch(function(error) {
            console.error('Play failed:', error);
            hideLoadingSpinner();
            
            // Try to provide more specific error information
            if (error.name === 'NotSupportedError') {
              console.error('Video format not supported by this browser/device');
            } else if (error.name === 'NotAllowedError') {
              console.error('Video play not allowed - may need user interaction first');
            }
          });
        }
      } catch (e) {
        console.error('Error in play:', e);
        hideLoadingSpinner();
      }
    }

    function pause() {
      if (!videoElement || !isVideoInitialized) {
        console.log('Video not initialized for pause');
        return;
      }
      try {
        videoElement.pause();
      } catch (e) {
        console.error('Error in pause:', e);
      }
    }

    function seekTo(position) {
      if (!videoElement || !isVideoInitialized) {
        console.log('Video not initialized for seekTo');
        return;
      }
      try {
        videoElement.currentTime = position;
      } catch (e) {
        console.error('Error in seekTo:', e);
      }
    }

    function setMute(mute) {
      if (!videoElement || !isVideoInitialized) {
        console.log('Video not initialized for setMute');
        return;
      }
      try {
        videoElement.muted = mute;
      } catch (e) {
        console.error('Error in setMute:', e);
      }
    }
  </script>
</body>

</html>
""";
}
