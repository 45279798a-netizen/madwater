// Stand-in for the artifact page's "room" capability when testing the web build locally:
// tabs of the same origin talk over a BroadcastChannel. Same call shapes as the real one
// (presence / onPeers / peers / join -> {emit, on, presence, peers, onPeers, connected, leave}).
window.MWMock = function () {
	const peer = Math.random().toString(36).slice(2, 10);
	const bc = new BroadcastChannel('mw-mock');
	function makeRoom(name) {
		const state = { pres: {}, peers: new Map(), subs: {}, peerSubs: [], left: false };
		(window.__mw = window.__mw || []).push({ name, state });
		const self = () => ({ peer, by: null, isMe: true, sameTab: true, kind: 'viewer', guest: false, presence: state.pres, updatedAt: Date.now() });
		function list() {
			const now = Date.now();
			const out = [self()];
			for (const [k, v] of state.peers) {
				if (now - v.seen < 30000) out.push({ peer: k, by: null, isMe: false, sameTab: false, kind: 'viewer', guest: false, presence: v.pres, updatedAt: v.seen });
			}
			return out;
		}
		function changed() { const ps = list(); state.peerSubs.forEach(f => f({ peers: ps, joined: [], left: [], updated: [] })); }
		function announce() { if (!state.left) bc.postMessage({ room: name, t: 'pres', peer, pres: state.pres }); }
		const beat = setInterval(() => { announce(); changed(); }, 700);
		bc.addEventListener('message', ev => {
			const m = ev.data;
			if (m.room !== name || m.peer === peer || state.left) return;
			if (m.t === 'pres') {
				const known = state.peers.has(m.peer);
				state.peers.set(m.peer, { pres: m.pres, seen: Date.now() });
				if (!known) announce();
				changed();
			} else if (m.t === 'bye') {
				state.peers.delete(m.peer);
				changed();
			} else if (m.t === 'msg') {
				(state.subs[m.topic] || []).forEach(f => f({ topic: m.topic, data: m.data, peer: m.peer, by: null, isMe: false, sameTab: false, kind: 'viewer', guest: false }));
			}
		});
		setTimeout(announce, 10);
		return {
			name,
			emit(topic, data) {
				bc.postMessage({ room: name, t: 'msg', peer, topic, data });
				(state.subs[topic] || []).forEach(f => f({ topic, data, peer, by: null, isMe: true, sameTab: true, kind: 'viewer', guest: false }));
				return Promise.resolve();
			},
			on(topic, fn) { (state.subs[topic] = state.subs[topic] || []).push(fn); return () => {}; },
			presence(patch) {
				for (const k in patch) { if (patch[k] === null) delete state.pres[k]; else state.pres[k] = patch[k]; }
				announce();
				return Promise.resolve();
			},
			peers: list,
			onPeers(fn) { state.peerSubs.push(fn); setTimeout(() => fn({ peers: list(), joined: list(), left: [], updated: [] }), 0); return () => {}; },
			connected() { return true; },
			onConnection(fn) { setTimeout(() => fn(true), 0); return () => {}; },
			leave() { state.left = true; clearInterval(beat); bc.postMessage({ room: name, t: 'bye', peer }); return Promise.resolve(); },
		};
	}
	const lobby = makeRoom('__lobby');
	lobby.join = name => Promise.resolve(makeRoom(name));
	return lobby;
};
