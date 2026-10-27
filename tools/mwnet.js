// window.MWNet: the bridge between the game (scripts/net.gd, via JavaScriptBridge) and whatever
// connects players on this page. The game polls; everything crosses as JSON text.
//
//  kind "room": inside Claude, the page's "room" capability (everyone viewing the page right now).
//               The lobby carries open rooms in each host's presence ({mw: code}); a game is a
//               named room "mw-<code>" whose presence carries each player's state under "g".
//  kind "peer": anywhere else (GitHub Pages), PeerJS / WebRTC with a 4-digit room code. The host's
//               peer id is "madwater-<code>"; friends connect straight to it and the host relays
//               everyone's presence. No lobby list: friends type the code.
//  kind "mock": tests (tests/web/mock_room.js), same shapes as "room".
(function () {
	const Q = [];
	let kind = 'none', lobby = null, user = null, game = null, me = '', avail = 'wait', joined = '';
	let peersDirty = false, lobbyDirty = true;
	const names = {};
	function push(e) { Q.push(e); if (Q.length > 800) Q.splice(0, Q.length - 800); }
	function onErr(e) { push({ k: 'err', code: (e && e.code) || 'upstream_error' }); }
	async function resolve(list) {
		if (!user || !user.profiles) return;
		const ids = list.map(p => p.by).filter(b => b && !(b in names));
		if (!ids.length) return;
		ids.forEach(i => { names[i] = ''; });
		try {
			const ps = await user.profiles(ids);
			for (const i of ids) names[i] = (ps && ps[i] && ps[i].name) || '';
			peersDirty = true; lobbyDirty = true;
		} catch (e) { /* names are optional */ }
	}
	function snap(list) {
		return list.filter(p => p.kind !== 'agent').map(p => ({
			peer: p.peer, me: !!p.sameTab, name: (p.by && names[p.by]) || '', p: p.presence || {},
		}));
	}

	// ------------------------------------------------------------ PeerJS rooms (outside Claude)
	function peerOptions() {
		const q = new URLSearchParams(location.search);
		const o = { debug: 0 };
		if (q.get('peerhost')) {   // tests: a local PeerJS server
			o.host = q.get('peerhost');
			o.port = Number(q.get('peerport') || 9000);
			o.path = q.get('peerpath') || '/';
			o.secure = false;
			o.config = { iceServers: [] };
		}
		return o;
	}
	function makePeerApi() {
		const P = window.Peer;
		let peer = null, conns = new Map(), hostConn = null, role = '', myPres = {}, list = [], lastSent = 0, timer = null;
		function selfEntry() { return { peer: me, sameTab: true, kind: 'viewer', by: null, presence: myPres }; }
		function hostBroadcastPeers() {
			const all = [{ peer: me, p: myPres }];
			for (const [id, c] of conns) all.push({ peer: id, p: c.pres || {} });
			const msg = { t: 'peers', list: all };
			for (const c of conns.values()) if (c.open) c.send(msg);
		}
		function close() {
			if (timer) clearInterval(timer);
			timer = null;
			for (const c of conns.values()) { try { c.close(); } catch (e) { /* ignore */ } }
			conns.clear();
			if (hostConn) { try { hostConn.close(); } catch (e) { /* ignore */ } }
			hostConn = null;
			if (peer) { try { peer.destroy(); } catch (e) { /* ignore */ } }
			peer = null;
			list = [];
			role = '';
		}
		function join(name, r) {
			close();
			role = r;
			const code = name.replace(/^mw-/, '');
			const opts = peerOptions();
			if (role === 'host') {
				peer = new P('madwater-' + code, opts);
				peer.on('open', id => {
					me = id;
					push({ k: 'joined', ok: true });
					timer = setInterval(hostBroadcastPeers, 100);
				});
				peer.on('connection', c => {
					c.on('open', () => { conns.set(c.peer, c); peersDirty = true; });
					c.on('data', m => {
						if (!m || typeof m !== 'object') return;
						if (m.t === 'pres') { c.pres = m.p; peersDirty = true; }
						else if (m.t === 'msg') push({ k: 'msg', topic: m.topic, peer: c.peer, me: false, data: m.data });
					});
					c.on('close', () => { conns.delete(c.peer); peersDirty = true; });
					c.on('error', () => { conns.delete(c.peer); peersDirty = true; });
				});
			} else {
				peer = new P(opts);
				peer.on('open', id => {
					me = id;
					hostConn = peer.connect('madwater-' + code, { reliable: true, serialization: 'json' });
					hostConn.on('open', () => { push({ k: 'joined', ok: true }); peersDirty = true; });
					hostConn.on('data', m => {
						if (!m || typeof m !== 'object') return;
						if (m.t === 'peers') { list = m.list || []; peersDirty = true; }
						else if (m.t === 'msg') push({ k: 'msg', topic: m.topic, peer: m.from || 'madwater-' + code, me: false, data: m.data });
					});
					hostConn.on('close', () => { list = []; peersDirty = true; });
				});
			}
			peer.on('error', e => {
				const t = e && e.type;
				if (t === 'unavailable-id') push({ k: 'joined', ok: false, code: 'taken' });
				else if (t === 'peer-unavailable') push({ k: 'joined', ok: false, code: 'no_room' });
				else if (t === 'network' || t === 'server-error' || t === 'socket-error' || t === 'socket-closed') push({ k: 'joined', ok: false, code: 'network' });
				else push({ k: 'err', code: t || 'upstream_error' });
			});
			peer.on('disconnected', () => { try { peer && !peer.destroyed && peer.reconnect(); } catch (e) { /* ignore */ } });
		}
		return {
			join,
			leave: close,
			emit(topic, data) {
				if (role === 'host') {
					const m = { t: 'msg', topic, data, from: me };
					for (const c of conns.values()) if (c.open) c.send(m);
				} else if (hostConn && hostConn.open) {
					hostConn.send({ t: 'msg', topic, data });
				}
			},
			presence(p) {
				myPres = p;
				if (role === 'client' && hostConn && hostConn.open) hostConn.send({ t: 'pres', p });
				else if (role === 'host') peersDirty = true;
			},
			peers() {
				const out = [selfEntry()];
				if (role === 'host') {
					for (const [id, c] of conns) out.push({ peer: id, sameTab: false, kind: 'viewer', by: null, presence: c.pres || {} });
				} else {
					for (const e of list) if (e.peer !== me) out.push({ peer: e.peer, sameTab: false, kind: 'viewer', by: null, presence: e.p || {} });
				}
				return out;
			},
			connected() { return role === 'host' ? !!(peer && peer.open) : !!(hostConn && hostConn.open); },
		};
	}
	let peerApi = null;

	async function init() {
		let api = null;
		const C = window.claude;
		if (C && typeof C.use === 'function') {
			try { api = await C.use('room'); } catch (e) { api = null; }
			try { user = await C.use('user'); } catch (e) { user = null; }
		}
		if (api) {
			kind = 'room';
		} else if (typeof window.MWMock === 'function') {
			api = window.MWMock();
			kind = 'mock';
		} else if (typeof window.Peer === 'function') {
			peerApi = makePeerApi();
			kind = 'peer';
			me = 'p' + Math.random().toString(36).slice(2, 8);
			avail = 'yes';
			return;
		}
		if (!api) { avail = 'no'; return; }
		lobby = api;
		avail = 'yes';
		lobby.onPeers(ch => {
			for (const p of ch.peers) if (p.sameTab) me = p.peer;
			lobbyDirty = true;
			resolve(ch.peers);
		}, e => { avail = 'no'; onErr(e); });
	}

	window.MWNet = {
		status() {
			return JSON.stringify({ avail, me, joined, kind, conn: game ? game.connected() : (peerApi ? peerApi.connected() : false) });
		},
		lobbySet(json) {
			if (lobby) lobby.presence(JSON.parse(json)).catch(onErr);
		},
		join(name, role) {
			if (peerApi) { joined = name; peerApi.join(name, role || 'client'); return; }
			if (!lobby) { push({ k: 'joined', ok: false, code: 'not_granted' }); return; }
			if (game) { try { game.leave(); } catch (e) { /* ignore */ } game = null; }
			lobby.join(name).then(r => {
				game = r;
				joined = name;
				for (const t of ['w', 'a', 'j', 'x']) {
					r.on(t, m => push({ k: 'msg', topic: t, peer: m.peer, me: !!m.sameTab, data: m.data }), onErr);
				}
				r.onPeers(ch => { peersDirty = true; resolve(ch.peers); }, onErr);
				peersDirty = true;
				push({ k: 'joined', ok: true });
			}, e => push({ k: 'joined', ok: false, code: (e && e.code) || 'upstream_error' }));
		},
		leave() {
			if (peerApi) peerApi.leave();
			if (game) { try { game.leave(); } catch (e) { /* ignore */ } }
			game = null;
			joined = '';
		},
		emit(topic, json) {
			if (peerApi) { peerApi.emit(topic, JSON.parse(json)); return; }
			if (game) game.emit(topic, JSON.parse(json)).catch(onErr);
		},
		presence(json) {
			if (peerApi) { peerApi.presence({ g: JSON.parse(json) }); return; }
			if (game) game.presence({ g: JSON.parse(json) }).catch(onErr);
		},
		poll() {
			const out = { ev: Q.splice(0) };
			if (peersDirty && (game || peerApi)) { peersDirty = false; out.peers = snap(game ? game.peers() : peerApi.peers()); }
			if (lobbyDirty && lobby) { lobbyDirty = false; out.lobby = snap(lobby.peers()); }
			return JSON.stringify(out);
		},

		// ------------------------------------------------------------ full screen / home screen
		screen() {
			const d = document;
			const standalone = !!(navigator.standalone || matchMedia('(display-mode: fullscreen)').matches || matchMedia('(display-mode: standalone)').matches);
			const can = !!(d.fullscreenEnabled || d.webkitFullscreenEnabled);
			const ios = /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
			return JSON.stringify({ standalone, can: can && !standalone, full: !!(d.fullscreenElement || d.webkitFullscreenElement), ios });
		},
		fullscreen() {
			const el = document.documentElement;
			const rq = el.requestFullscreen || el.webkitRequestFullscreen;
			if (!rq) return 'no';
			try {
				const p = rq.call(el, { navigationUI: 'hide' });
				const lock = () => { try { screen.orientation.lock('landscape').catch(() => {}); } catch (e) { /* ignore */ } };
				if (p && p.then) p.then(lock, () => {}); else lock();
			} catch (e) { return 'no'; }
			return 'ok';
		},
	};
	init();
})();
