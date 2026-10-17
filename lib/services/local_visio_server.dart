import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Participant connecté au serveur local de visioconférence
class LocalVisioPeer {
  final String id;
  final String name;
  final String role;
  final bool micOn;
  final bool camOn;
  final bool handRaised;
  final String joinedAt;
  final WebSocket? socket;

  const LocalVisioPeer({
    required this.id,
    required this.name,
    required this.role,
    this.micOn = true,
    this.camOn = true,
    this.handRaised = false,
    required this.joinedAt,
    this.socket,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'micOn': micOn,
        'camOn': camOn,
        'handRaised': handRaised,
        'joinedAt': joinedAt,
      };

  LocalVisioPeer copyWith({
    String? name,
    String? role,
    bool? micOn,
    bool? camOn,
    bool? handRaised,
  }) {
    return LocalVisioPeer(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      micOn: micOn ?? this.micOn,
      camOn: camOn ?? this.camOn,
      handRaised: handRaised ?? this.handRaised,
      joinedAt: joinedAt,
      socket: socket,
    );
  }
}

/// Message instantané de visioconférence locale
class LocalVisioChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String text;
  final String time;

  const LocalVisioChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'text': text,
        'time': time,
      };
}

/// État du serveur local de visioconférence
class LocalVisioServerState {
  final bool isRunning;
  final String? localIp;
  final int port;
  final String roomId;
  final String roomTitle;
  final List<LocalVisioPeer> peers;
  final List<LocalVisioChatMessage> messages;
  final String? lastError;

  const LocalVisioServerState({
    this.isRunning = false,
    this.localIp,
    this.port = 8088,
    this.roomId = 'ICT313_AMPHI502_2026',
    this.roomTitle = 'ICT313 · Architecture des Ordinateurs & Systèmes',
    this.peers = const [],
    this.messages = const [],
    this.lastError,
  });

  /// URL directe sur le réseau local Wi-Fi / LAN (zéro connexion Internet requise)
  String get lanUrl {
    final ip = localIp ?? '127.0.0.1';
    return 'http://$ip:$port/visio?room=${Uri.encodeComponent(roomId)}';
  }

  /// URL Web publique (accessible par les participants à distance via Internet)
  String get webFallbackUrl {
    return 'https://uniflow.kernelforge.codes/#/visio?room=${Uri.encodeComponent(roomId)}';
  }

  LocalVisioServerState copyWith({
    bool? isRunning,
    String? localIp,
    int? port,
    String? roomId,
    String? roomTitle,
    List<LocalVisioPeer>? peers,
    List<LocalVisioChatMessage>? messages,
    String? lastError,
  }) {
    return LocalVisioServerState(
      isRunning: isRunning ?? this.isRunning,
      localIp: localIp ?? this.localIp,
      port: port ?? this.port,
      roomId: roomId ?? this.roomId,
      roomTitle: roomTitle ?? this.roomTitle,
      peers: peers ?? this.peers,
      messages: messages ?? this.messages,
      lastError: lastError,
    );
  }
}

/// Service autonome de Visioconférence Embarquée en Local
///
/// Démarre un serveur HTTP + WebSocket sur la machine (Linux, Windows, macOS, Android).
/// Sert une application Web complète autonome pour les participants sans application,
/// et gère le canal de signalisation WebRTC pour la transmission vidéo/audio P2P.
class LocalVisioServerNotifier extends StateNotifier<LocalVisioServerState> {
  HttpServer? _server;
  final Map<String, WebSocket> _sockets = {};

  LocalVisioServerNotifier() : super(const LocalVisioServerState()) {
    _detectLocalIp();
  }

  /// Détecte l'adresse IP IPv4 sur le réseau local
  Future<void> _detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      String? bestIp;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
            bestIp = ip;
            break;
          }
        }
        if (bestIp != null) break;
      }
      bestIp ??= (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty)
          ? interfaces.first.addresses.first.address
          : '127.0.0.1';
      state = state.copyWith(localIp: bestIp);
    } catch (_) {
      state = state.copyWith(localIp: '127.0.0.1');
    }
  }

  /// Démarre le serveur local autonome
  Future<bool> startServer({
    int port = 8088,
    String? roomId,
    String? roomTitle,
  }) async {
    if (state.isRunning) return true;

    try {
      await _detectLocalIp();
      final targetRoomId = roomId ?? state.roomId;
      final targetRoomTitle = roomTitle ?? state.roomTitle;

      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );

      state = state.copyWith(
        isRunning: true,
        port: port,
        roomId: targetRoomId,
        roomTitle: targetRoomTitle,
        lastError: null,
      );

      _server!.listen(_handleHttpRequest, onError: (e) {
        state = state.copyWith(lastError: e.toString());
      });

      return true;
    } catch (e) {
      state = state.copyWith(
        isRunning: false,
        lastError: 'Impossible de démarrer le serveur visio sur le port $port : $e',
      );
      return false;
    }
  }

  /// Arrête le serveur local et ferme les connexions
  Future<void> stopServer() async {
    for (final ws in _sockets.values) {
      try {
        await ws.close(WebSocketStatus.normalClosure, 'Serveur arrêté par l\'hôte');
      } catch (_) {}
    }
    _sockets.clear();
    await _server?.close(force: true);
    _server = null;

    state = state.copyWith(
      isRunning: false,
      peers: [],
    );
  }

  /// Gère les requêtes HTTP et les upgrades WebSocket
  void _handleHttpRequest(HttpRequest request) async {
    // Entêtes CORS universelles pour l'interopérabilité
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.set('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    // 1. Upgrade WebSocket pour la signalisation WebRTC
    if (path == '/ws') {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        try {
          final ws = await WebSocketTransformer.upgrade(request);
          _handleWebSocketClient(ws);
        } catch (e) {
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
        }
      } else {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
      }
      return;
    }

    // 2. Statut JSON du serveur
    if (path == '/status' || path == '/api/status') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': 'online',
        'service': 'UniFlow Local Visio Conference Hub',
        'version': '2.0.0',
        'roomId': state.roomId,
        'roomTitle': state.roomTitle,
        'peersCount': state.peers.length,
        'peers': state.peers.map((p) => p.toJson()).toList(),
      }));
      await request.response.close();
      return;
    }

    // 3. Application Web Visio intégrée pour invités sans l'application
    if (path == '/visio' || path == '/join' || path == '/') {
      request.response.headers.contentType = ContentType.html;
      request.response.write(_generateStandaloneWebVisioHtml());
      await request.response.close();
      return;
    }

    // Fallback 404
    request.response.statusCode = HttpStatus.notFound;
    request.response.write('UniFlow Local Visio Server - Endpoint non trouvé.');
    await request.response.close();
  }

  /// Traitement des messages WebSocket WebRTC
  void _handleWebSocketClient(WebSocket ws) {
    String? peerId;

    ws.listen(
      (data) {
        try {
          final message = jsonDecode(data as String) as Map<String, dynamic>;
          final type = message['type'] as String?;

          switch (type) {
            case 'join':
              peerId = message['peerId'] as String? ?? 'peer_${DateTime.now().millisecondsSinceEpoch}';
              final name = message['name'] as String? ?? 'Invité Web';
              final role = message['role'] as String? ?? 'INVITÉ';
              final micOn = message['micOn'] as bool? ?? true;
              final camOn = message['camOn'] as bool? ?? true;

              _sockets[peerId!] = ws;

              final newPeer = LocalVisioPeer(
                id: peerId!,
                name: name,
                role: role,
                micOn: micOn,
                camOn: camOn,
                joinedAt: '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                socket: ws,
              );

              final updatedPeers = List<LocalVisioPeer>.from(state.peers)
                ..removeWhere((p) => p.id == peerId)
                ..add(newPeer);

              state = state.copyWith(peers: updatedPeers);

              // Accusé de bienvenue au nouveau pair avec l'état de la salle
              ws.add(jsonEncode({
                'type': 'welcome',
                'roomId': state.roomId,
                'roomTitle': state.roomTitle,
                'peers': updatedPeers.map((p) => p.toJson()).toList(),
              }));

              // Notification aux autres pairs
              _broadcastExcept(
                peerId!,
                jsonEncode({
                  'type': 'peer-joined',
                  'peer': newPeer.toJson(),
                }),
              );
              break;

            case 'signal':
              // Relai SDP offer, answer, ICE candidate WebRTC vers la cible
              final targetId = message['targetId'] as String?;
              if (targetId != null && _sockets.containsKey(targetId)) {
                _sockets[targetId]!.add(jsonEncode({
                  'type': 'signal',
                  'senderId': peerId,
                  'signalData': message['signalData'],
                }));
              }
              break;

            case 'chat':
              final text = message['text'] as String? ?? '';
              final senderName = message['senderName'] as String? ?? 'Participant';
              final senderRole = message['senderRole'] as String? ?? 'INVITÉ';
              final chatMsg = LocalVisioChatMessage(
                id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
                senderId: peerId ?? 'unknown',
                senderName: senderName,
                senderRole: senderRole,
                text: text,
                time: '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
              );

              state = state.copyWith(
                messages: [...state.messages, chatMsg],
              );

              _broadcastAll(jsonEncode({
                'type': 'chat',
                'message': chatMsg.toJson(),
              }));
              break;

            case 'state-change':
              if (peerId != null) {
                final mic = message['micOn'] as bool?;
                final cam = message['camOn'] as bool?;
                final hand = message['handRaised'] as bool?;

                final peersList = state.peers.map((p) {
                  if (p.id == peerId) {
                    return p.copyWith(
                      micOn: mic ?? p.micOn,
                      camOn: cam ?? p.camOn,
                      handRaised: hand ?? p.handRaised,
                    );
                  }
                  return p;
                }).toList();

                state = state.copyWith(peers: peersList);

                _broadcastExcept(
                  peerId!,
                  jsonEncode({
                    'type': 'state-change',
                    'peerId': peerId,
                    'micOn': mic,
                    'camOn': cam,
                    'handRaised': hand,
                  }),
                );
              }
              break;
          }
        } catch (_) {}
      },
      onDone: () => _removePeer(peerId),
      onError: (_) => _removePeer(peerId),
    );
  }

  void _removePeer(String? peerId) {
    if (peerId == null) return;
    _sockets.remove(peerId);
    final updatedPeers = List<LocalVisioPeer>.from(state.peers)..removeWhere((p) => p.id == peerId);
    state = state.copyWith(peers: updatedPeers);

    _broadcastAll(jsonEncode({
      'type': 'peer-left',
      'peerId': peerId,
    }));
  }

  void _broadcastAll(String data) {
    for (final ws in _sockets.values) {
      try {
        ws.add(data);
      } catch (_) {}
    }
  }

  void _broadcastExcept(String exceptId, String data) {
    _sockets.forEach((id, ws) {
      if (id != exceptId) {
        try {
          ws.add(data);
        } catch (_) {}
      }
    });
  }

  /// Page Web autonome servie directement par le serveur local pour les invités sans application
  String _generateStandaloneWebVisioHtml() {
    final title = state.roomTitle;
    final roomId = state.roomId;

    return '''<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>UniFlow Visio · $title</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Plus Jakarta Sans', system-ui, sans-serif; }
    body { background-color: #0B1120; color: #F8FAFC; height: 100vh; overflow: hidden; display: flex; flex-direction: column; }
    
    /* Header */
    header {
      background: rgba(15, 23, 42, 0.85);
      backdrop-filter: blur(12px);
      border-bottom: 1px solid rgba(255, 255, 255, 0.08);
      padding: 12px 24px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      z-index: 20;
    }
    .brand { display: flex; align-items: center; gap: 12px; }
    .brand-logo { width: 36px; height: 36px; background: linear-gradient(135deg, #1E3A8A, #0D9488); border-radius: 10px; display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 18px; color: white; }
    .room-info h1 { font-size: 15px; font-weight: 700; color: #F8FAFC; }
    .room-info p { font-size: 12px; color: #94A3B8; display: flex; align-items: center; gap: 6px; }
    .badge-live { background: #EF4444; color: white; padding: 2px 8px; border-radius: 999px; font-size: 10px; font-weight: 700; text-transform: uppercase; animation: pulse 2s infinite; }
    
    /* Layout */
    .main-container { flex: 1; display: flex; position: relative; overflow: hidden; }
    .video-stage { flex: 1; display: flex; flex-direction: column; padding: 16px; position: relative; gap: 12px; }
    
    /* Video Grid */
    .video-grid { flex: 1; display: grid; gap: 16px; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); align-content: center; justify-content: center; }
    .video-card {
      background: #1E293B;
      border-radius: 20px;
      overflow: hidden;
      position: relative;
      display: flex;
      align-items: center;
      justify-content: center;
      border: 2px solid rgba(255, 255, 255, 0.05);
      box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.5);
      aspect-ratio: 16 / 9;
      max-height: 80vh;
    }
    .video-card.speaking { border-color: #10B981; box-shadow: 0 0 20px rgba(16, 185, 129, 0.35); }
    .video-card video { width: 100%; height: 100%; object-fit: cover; }
    .video-placeholder { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 12px; }
    .avatar-circle { width: 84px; height: 84px; border-radius: 50%; background: linear-gradient(135deg, #1E3A8A, #3B82F6); display: flex; align-items: center; justify-content: center; font-size: 32px; font-weight: 700; color: white; box-shadow: 0 8px 16px rgba(0,0,0,0.3); }
    .video-badge { position: absolute; bottom: 12px; left: 12px; background: rgba(15, 23, 42, 0.75); backdrop-filter: blur(8px); padding: 6px 12px; border-radius: 10px; font-size: 12px; font-weight: 600; display: flex; align-items: center; gap: 8px; border: 1px solid rgba(255,255,255,0.1); }
    
    /* Controls Bar */
    .controls-bar {
      height: 76px;
      background: rgba(15, 23, 42, 0.9);
      backdrop-filter: blur(16px);
      border-top: 1px solid rgba(255, 255, 255, 0.08);
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 14px;
      padding: 0 20px;
      z-index: 20;
    }
    .btn-control {
      width: 48px;
      height: 48px;
      border-radius: 50%;
      border: none;
      background: #334155;
      color: white;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    }
    .btn-control:hover { background: #475569; transform: translateY(-2px); }
    .btn-control.off { background: #EF4444; color: white; }
    .btn-control.active { background: #10B981; color: white; }
    .btn-leave { width: 56px; height: 48px; border-radius: 24px; background: #DC2626; color: white; border: none; cursor: pointer; font-weight: 700; font-size: 13px; }
    .btn-leave:hover { background: #B91C1C; }
    
    /* Prejoin Modal / Lobby */
    .lobby-overlay {
      position: fixed; inset: 0; background: #0B1120; z-index: 100;
      display: flex; align-items: center; justify-content: center; padding: 20px;
    }
    .lobby-card {
      background: #1E293B; border-radius: 28px; width: 100%; max-width: 520px;
      padding: 32px; border: 1px solid rgba(255, 255, 255, 0.1);
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.7); text-align: center;
    }
    .lobby-preview {
      width: 100%; aspect-ratio: 16/9; background: #0F172A; border-radius: 20px;
      margin: 20px 0; overflow: hidden; position: relative; display: flex;
      align-items: center; justify-content: center; border: 1px solid rgba(255, 255, 255, 0.08);
    }
    .lobby-preview video { width: 100%; height: 100%; object-fit: cover; }
    .lobby-input {
      width: 100%; padding: 14px 18px; border-radius: 14px; background: #0F172A;
      border: 1px solid rgba(255, 255, 255, 0.15); color: white; font-size: 15px;
      margin-bottom: 20px; outline: none; transition: border-color 0.2s;
    }
    .lobby-input:focus { border-color: #3B82F6; }
    .btn-join {
      width: 100%; padding: 16px; border-radius: 14px; background: linear-gradient(135deg, #1E3A8A, #0D9488);
      color: white; border: none; font-size: 16px; font-weight: 700; cursor: pointer;
      box-shadow: 0 10px 20px -5px rgba(30, 58, 138, 0.5); transition: transform 0.2s;
    }
    .btn-join:hover { transform: scale(1.02); }
    
    /* Side Panel */
    .side-panel {
      width: 320px; background: #1E293B; border-left: 1px solid rgba(255, 255, 255, 0.08);
      display: flex; flex-direction: column; display: none;
    }
    .side-panel.open { display: flex; }
    .panel-header { padding: 16px 20px; border-bottom: 1px solid rgba(255, 255, 255, 0.08); font-weight: 700; font-size: 14px; display: flex; justify-content: space-between; align-items: center; }
    .panel-chat { flex: 1; overflow-y: auto; padding: 16px; display: flex; flex-direction: column; gap: 12px; }
    .chat-bubble { background: #334155; padding: 10px 14px; border-radius: 14px; font-size: 13px; max-width: 85%; }
    .chat-bubble.me { background: #1E3A8A; align-self: flex-end; }
    .chat-sender { font-size: 11px; font-weight: 700; color: #93C5FD; margin-bottom: 3px; }
    .chat-input-bar { padding: 14px; border-top: 1px solid rgba(255, 255, 255, 0.08); display: flex; gap: 8px; }
    .chat-input { flex: 1; padding: 10px 14px; border-radius: 10px; background: #0F172A; border: 1px solid rgba(255, 255, 255, 0.1); color: white; font-size: 13px; outline: none; }
    .btn-send { padding: 10px 16px; border-radius: 10px; background: #2563EB; border: none; color: white; cursor: pointer; font-weight: 600; font-size: 13px; }

    @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }
    @media (max-width: 768px) {
      .video-grid { grid-template-columns: 1fr; }
      .side-panel { position: absolute; inset: 0; width: 100%; z-index: 30; }
    }
  </style>
</head>
<body>

  <!-- Lobby Pré-connexion -->
  <div id="lobby" class="lobby-overlay">
    <div class="lobby-card">
      <div style="display:flex; align-items:center; justify-content:center; gap:10px; margin-bottom:12px;">
        <div class="brand-logo">U</div>
        <h2 style="font-size:20px; font-weight:800;">UniFlow Visio</h2>
      </div>
      <p style="font-size:13px; color:#94A3B8; margin-bottom:16px;">Séance : <strong>$title</strong></p>
      
      <div class="lobby-preview">
        <video id="previewVideo" autoplay playsinline muted></video>
        <div id="previewAvatar" class="avatar-circle" style="display:none;">?</div>
      </div>
      
      <div style="display:flex; justify-content:center; gap:12px; margin-bottom:20px;">
        <button id="toggleLobbyMic" class="btn-control active" title="Micro">🎤</button>
        <button id="toggleLobbyCam" class="btn-control active" title="Caméra">📹</button>
      </div>

      <input id="guestName" type="text" class="lobby-input" placeholder="Entrez votre nom ou prénom..." value="Invité \${Math.floor(100 + Math.random()*900)}">
      <button id="btnJoin" class="btn-join">Rejoindre la visioconférence</button>
      <p style="font-size:11px; color:#64748B; margin-top:14px;">⚡ Relais local Campus LAN 0 ms · Zéro installation requise</p>
    </div>
  </div>

  <!-- Header -->
  <header>
    <div class="brand">
      <div class="brand-logo">U</div>
      <div class="room-info">
        <h1>$title</h1>
        <p><span class="badge-live">EN DIRECT</span> Salle : $roomId · Campus Relais Local</p>
      </div>
    </div>
    <div style="display:flex; align-items:center; gap:12px;">
      <span id="participantsCountBadge" style="background:#1E293B; padding:6px 14px; border-radius:999px; font-size:12px; font-weight:700; color:#38BDF8;">👥 1 connecté</span>
    </div>
  </header>

  <!-- Container Principal -->
  <div class="main-container">
    <div class="video-stage">
      <div id="videoGrid" class="video-grid">
        <!-- Carte vidéo locale -->
        <div id="localCard" class="video-card">
          <video id="localVideo" autoplay playsinline muted></video>
          <div id="localAvatar" class="video-placeholder" style="display:none;">
            <div id="localAvatarCircle" class="avatar-circle">M</div>
          </div>
          <div class="video-badge">
            <span id="localLabel">Moi (Invité)</span>
            <span id="localMicIndicator">🎤</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Volet latéral Chat -->
    <div id="sidePanel" class="side-panel">
      <div class="panel-header">
        <span>Discussion en direct</span>
        <button id="closePanel" style="background:none; border:none; color:#94A3B8; font-size:18px; cursor:pointer;">✕</button>
      </div>
      <div id="chatMessages" class="panel-chat">
        <div class="chat-bubble">
          <div class="chat-sender">Système Campus</div>
          <div>Bienvenue sur la visioconférence locale UniFlow. Le flux est chiffré et ultra-fluide en LAN.</div>
        </div>
      </div>
      <div class="chat-input-bar">
        <input id="chatInput" type="text" class="chat-input" placeholder="Écrire un message...">
        <button id="btnSendChat" class="btn-send">Envoyer</button>
      </div>
    </div>
  </div>

  <!-- Barre de Contrôles Inférieure -->
  <div class="controls-bar">
    <button id="btnMic" class="btn-control active" title="Micro (Mute / Unmute)">🎤</button>
    <button id="btnCam" class="btn-control active" title="Caméra (On / Off)">📹</button>
    <button id="btnScreen" class="btn-control" title="Partager l'écran">🖥️</button>
    <button id="btnHand" class="btn-control" title="Lever la main">✋</button>
    <button id="btnChat" class="btn-control" title="Chat">💬</button>
    <button id="btnLeave" class="btn-leave" title="Quitter la réunion">Quitter</button>
  </div>

  <script>
    let localStream = null;
    let ws = null;
    let myPeerId = 'peer_' + Math.random().toString(36).substring(2, 9);
    let myName = '';
    let micActive = true;
    let camActive = true;
    let handRaised = false;

    const previewVideo = document.getElementById('previewVideo');
    const localVideo = document.getElementById('localVideo');
    const localCard = document.getElementById('localCard');
    const localAvatar = document.getElementById('localAvatar');
    const localAvatarCircle = document.getElementById('localAvatarCircle');
    const localLabel = document.getElementById('localLabel');
    const localMicIndicator = document.getElementById('localMicIndicator');
    const videoGrid = document.getElementById('videoGrid');
    const sidePanel = document.getElementById('sidePanel');
    const chatMessages = document.getElementById('chatMessages');
    const chatInput = document.getElementById('chatInput');
    const participantsCountBadge = document.getElementById('participantsCountBadge');

    // Démarrage de la caméra pour le lobby
    async function initLobbyMedia() {
      try {
        localStream = await navigator.mediaDevices.getUserMedia({
          video: { width: { ideal: 1280 }, height: { ideal: 720 } },
          audio: true
        });
        previewVideo.srcObject = localStream;
        localVideo.srcObject = localStream;
      } catch (err) {
        console.warn('Accès média refusé ou indisponible:', err);
        camActive = false;
        micActive = false;
        document.getElementById('previewAvatar').style.display = 'flex';
        previewVideo.style.display = 'none';
      }
    }

    initLobbyMedia();

    // Toggle Lobby Controls
    document.getElementById('toggleLobbyMic').onclick = () => {
      micActive = !micActive;
      if (localStream) localStream.getAudioTracks().forEach(t => t.enabled = micActive);
      document.getElementById('toggleLobbyMic').className = 'btn-control ' + (micActive ? 'active' : 'off');
    };

    document.getElementById('toggleLobbyCam').onclick = () => {
      camActive = !camActive;
      if (localStream) localStream.getVideoTracks().forEach(t => t.enabled = camActive);
      document.getElementById('toggleLobbyCam').className = 'btn-control ' + (camActive ? 'active' : 'off');
      previewVideo.style.display = camActive ? 'block' : 'none';
      document.getElementById('previewAvatar').style.display = camActive ? 'none' : 'flex';
    };

    // Rejoindre la réunion
    document.getElementById('btnJoin').onclick = () => {
      myName = document.getElementById('guestName').value.trim() || 'Invité';
      localLabel.textContent = myName + ' (Moi)';
      localAvatarCircle.textContent = myName.charAt(0).toUpperCase();
      
      document.getElementById('lobby').style.display = 'none';
      connectWebSocket();
    };

    // Connexion WebSocket
    function connectWebSocket() {
      const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      const wsUrl = protocol + '//' + window.location.host + '/ws';
      
      ws = new WebSocket(wsUrl);

      ws.onopen = () => {
        ws.send(JSON.stringify({
          type: 'join',
          peerId: myPeerId,
          name: myName,
          role: 'INVITÉ',
          micOn: micActive,
          camOn: camActive
        }));
      };

      ws.onmessage = (event) => {
        try {
          const msg = JSON.parse(event.data);
          handleServerMessage(msg);
        } catch(e) {}
      };

      ws.onclose = () => {
        addSystemChat('Déconnecté du relais local. Tentative de reconnexion...');
        setTimeout(connectWebSocket, 3000);
      };
    }

    function handleServerMessage(msg) {
      if (msg.type === 'welcome') {
        participantsCountBadge.textContent = '👥 ' + msg.peers.length + ' connectés';
      } else if (msg.type === 'peer-joined') {
        addSystemChat(msg.peer.name + ' a rejoint la session.');
      } else if (msg.type === 'peer-left') {
        addSystemChat('Un participant a quitté la session.');
      } else if (msg.type === 'chat') {
        renderChatBubble(msg.message);
      }
    }

    function addSystemChat(text) {
      const b = document.createElement('div');
      b.className = 'chat-bubble';
      b.innerHTML = '<div style="color:#64748B; font-style:italic;">' + text + '</div>';
      chatMessages.appendChild(b);
      chatMessages.scrollTop = chatMessages.scrollHeight;
    }

    function renderChatBubble(m) {
      const isMe = m.senderId === myPeerId;
      const b = document.createElement('div');
      b.className = 'chat-bubble ' + (isMe ? 'me' : '');
      b.innerHTML = '<div class="chat-sender">' + m.senderName + ' · ' + m.time + '</div><div>' + m.text + '</div>';
      chatMessages.appendChild(b);
      chatMessages.scrollTop = chatMessages.scrollHeight;
    }

    // Contrôles en réunion
    const btnMic = document.getElementById('btnMic');
    btnMic.onclick = () => {
      micActive = !micActive;
      if (localStream) localStream.getAudioTracks().forEach(t => t.enabled = micActive);
      btnMic.className = 'btn-control ' + (micActive ? 'active' : 'off');
      localMicIndicator.textContent = micActive ? '🎤' : '🔇';
      sendStateChange();
    };

    const btnCam = document.getElementById('btnCam');
    btnCam.onclick = () => {
      camActive = !camActive;
      if (localStream) localStream.getVideoTracks().forEach(t => t.enabled = camActive);
      btnCam.className = 'btn-control ' + (camActive ? 'active' : 'off');
      localVideo.style.display = camActive ? 'block' : 'none';
      localAvatar.style.display = camActive ? 'none' : 'flex';
      sendStateChange();
    };

    const btnScreen = document.getElementById('btnScreen');
    btnScreen.onclick = async () => {
      try {
        const screenStream = await navigator.mediaDevices.getDisplayMedia({ video: true });
        localVideo.srcObject = screenStream;
        btnScreen.className = 'btn-control active';
        screenStream.getVideoTracks()[0].onended = () => {
          localVideo.srcObject = localStream;
          btnScreen.className = 'btn-control';
        };
      } catch (_) {}
    };

    const btnHand = document.getElementById('btnHand');
    btnHand.onclick = () => {
      handRaised = !handRaised;
      btnHand.className = 'btn-control ' + (handRaised ? 'active' : '');
      sendStateChange();
      if (handRaised) addSystemChat('✋ Vous avez levé la main.');
    };

    const btnChat = document.getElementById('btnChat');
    btnChat.onclick = () => sidePanel.classList.toggle('open');
    document.getElementById('closePanel').onclick = () => sidePanel.classList.remove('open');

    function sendStateChange() {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({
          type: 'state-change',
          peerId: myPeerId,
          micOn: micActive,
          camOn: camActive,
          handRaised: handRaised
        }));
      }
    }

    // Envoi de messages dans le chat
    document.getElementById('btnSendChat').onclick = sendChatMessage;
    chatInput.onkeypress = (e) => { if (e.key === 'Enter') sendChatMessage(); };

    function sendChatMessage() {
      const text = chatInput.value.trim();
      if (!text || !ws) return;
      ws.send(JSON.stringify({
        type: 'chat',
        senderId: myPeerId,
        senderName: myName,
        senderRole: 'INVITÉ',
        text: text
      }));
      chatInput.value = '';
    }

    document.getElementById('btnLeave').onclick = () => {
      if (confirm('Voulez-vous vraiment quitter la visioconférence ?')) {
        window.location.reload();
      }
    };
  </script>
</body>
</html>''';
  }
}

/// Provider Riverpod global pour le serveur local de visioconférence
final localVisioServerProvider =
    StateNotifierProvider<LocalVisioServerNotifier, LocalVisioServerState>((ref) {
  return LocalVisioServerNotifier();
});
