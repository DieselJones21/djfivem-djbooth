(() => {
    function detectFiveM() {
        try {
            if (typeof GetParentResourceName === 'function') {
                const name = GetParentResourceName();
                if (name && String(name).length) return true;
            }
        } catch (e) { /* ignore */ }
        try {
            if (typeof window.invokeNative === 'function') return true;
        } catch (e) { /* ignore */ }
        const href = String((window.location && window.location.href) || '');
        if (href.indexOf('nui://') === 0 || href.indexOf('https://cfx-nui-') === 0) return true;
        if (window.location && window.location.protocol === 'nui:') return true;
        return false;
    }

    const isFiveM = detectFiveM();
    const resourceName = () => {
        try {
            if (typeof GetParentResourceName === 'function') return GetParentResourceName();
        } catch (e) { /* ignore */ }
        return 'djbooth';
    };

    if (isFiveM) document.body.classList.add('fivem');

    const state = {
        tab: 'now',
        appName: 'Lumina',
        appTagline: 'Live Booth OS',
        booth: null,
        playback: emptyPlayback(),
        songs: [],
        playlists: [],
        isAdmin: false,
        playerName: 'DJ',
        mode: 'booth',
        booths: [],
        models: [],
        draft: null,
        speaker: null,
        nearby: [],
        canPickup: false,
        canPermanent: false,
        limits: { maxVolume: 1, minRadius: 8, maxRadius: 120 },
    };

    function emptyPlayback() {
        return {
            playing: false,
            paused: false,
            current: null,
            queue: [],
            volume: 0.68,
            radius: 40,
            loop: 'off',
            shuffle: false,
            elapsed: 0,
            duration: 0,
        };
    }

    const PREVIEW = {
        booth: {
            id: 'preview',
            name: 'Vanilla Unicorn',
            radius: 48,
            volume: 0.72,
            jobs: [{ name: 'unemployed', grade: 0 }],
            coords: { x: 127.2, y: -1283.4, z: 29.2 },
            speakers: [{ x: 1, y: 2, z: 3 }, { x: 4, y: 5, z: 6 }],
            model: 'prop_speaker_07',
        },
        playback: {
            playing: true,
            paused: false,
            current: { id: '1', title: 'Night Drive', author: 'Arcade Skyline', url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', duration: 238, thumbnail: '' },
            queue: [
                { id: '2', title: 'Pink Neon', author: 'City Bloom', url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', duration: 201 },
                { id: '3', title: 'After Hours', author: 'Luna Park', url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', duration: 186 },
                { id: '4', title: 'Velvet Pulse', author: 'Northside', url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', duration: 224 },
            ],
            volume: 0.72,
            radius: 48,
            loop: 'queue',
            shuffle: false,
            elapsed: 86,
            duration: 238,
        },
        songs: [
            { id: 's1', title: 'Night Drive', author: 'Arcade Skyline', url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' },
            { id: 's2', title: 'Sunroof Disco', author: 'Kite Club', url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' },
            { id: 's3', title: 'Coastline', author: 'Marigold', url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' },
        ],
        playlists: [
            { id: 'p1', name: 'Friday Peak', tracks: [
                { id: 's1', title: 'Night Drive', author: 'Arcade Skyline', url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' },
                { id: 's2', title: 'Sunroof Disco', author: 'Kite Club', url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' },
            ]},
            { id: 'p2', name: 'Warmup', tracks: [
                { id: 's3', title: 'Coastline', author: 'Marigold', url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' },
            ]},
        ],
        booths: [
            { id: 'preview', name: 'Vanilla Unicorn', jobs: [{ name: 'unemployed', grade: 0 }], radius: 48, coords: { x: 127.2, y: -1283.4, z: 29.2 }, speakers: [{}, {}], model: 'prop_speaker_07' },
            { id: 'b2', name: 'Bahama Mamas', jobs: [], radius: 36, coords: { x: -1388.0, y: -586.4, z: 30.2 }, speakers: [], model: 'prop_speaker_07' },
        ],
        models: [
            { model: 'prop_speaker_07', label: 'Tall Speaker' },
            { model: 'ba_prop_battle_dj_stand', label: 'After Hours Stand' },
            { model: 'sf_prop_sf_dj_desk_02a', label: 'Club DJ Desk' },
        ],
    };

    const icons = {
        now: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
        queue: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 6h16M4 12h10M4 18h16"/><path d="M16 10l4 2-4 2"/></svg>',
        library: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 5h4v14H4zM10 5h4v14h-4zM16 5h4v14h-4z"/></svg>',
        playlists: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M8 6h13M8 12h13M8 18h13"/><circle cx="4" cy="6" r="1.2" fill="currentColor"/><circle cx="4" cy="12" r="1.2" fill="currentColor"/><circle cx="4" cy="18" r="1.2" fill="currentColor"/></svg>',
        mixer: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 4v16M12 4v16M18 4v16"/><circle cx="6" cy="9" r="2" fill="currentColor"/><circle cx="12" cy="14" r="2" fill="currentColor"/><circle cx="18" cy="8" r="2" fill="currentColor"/></svg>',
        admin: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="4" y="4" width="16" height="16" rx="3"/><path d="M8 9h8M8 13h5"/></svg>',
        play: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>',
        pause: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M7 5h4v14H7zM13 5h4v14h-4z"/></svg>',
        prev: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h2v12H6zM18 6v12L9 12z"/></svg>',
        next: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M16 6h2v12h-2zM6 6l9 6-9 6z"/></svg>',
        stop: '<svg viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="6" width="12" height="12" rx="2"/></svg>',
        save: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 21H5a2 2 0 0 1-2-2V5h14l4 4v12a2 2 0 0 1-2 2z"/><path d="M17 21v-8H7v8M7 5v4h8"/></svg>',
        close: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 6l12 12M18 6L6 18"/></svg>',
        up: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 14l6-6 6 6"/></svg>',
        down: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 10l6 6 6-6"/></svg>',
        trash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 7h14M10 7V5h4v2M8 7l1 12h6l1-12"/></svg>',
        plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 5v14M5 12h14"/></svg>',
        pin: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 21s7-6.2 7-11a7 7 0 1 0-14 0c0 4.8 7 11 7 11z"/><circle cx="12" cy="10" r="2.2"/></svg>',
        shuffle: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 7h3l10 10h3M18 7h3M4 17h3"/><path d="M17 4l4 3-4 3M17 14l4 3-4 3"/></svg>',
        loop: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 1l4 4-4 4"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><path d="M7 23l-4-4 4-4"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg>',
    };

    const $ = (id) => document.getElementById(id);
    const esc = (value) => String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');

    function hue(text) {
        let h = 0;
        const s = String(text || 'lumina');
        for (let i = 0; i < s.length; i += 1) h = (h * 31 + s.charCodeAt(i)) % 360;
        return h;
    }

    function cover(track, extra = '') {
        const title = track?.title || 'Track';
        if (track?.thumbnail) {
            return `<div class="cover ${extra}" style="background-image:url('${esc(track.thumbnail)}')"></div>`;
        }
        return `<div class="cover cover-fallback ${extra}" style="--h:${hue(title)}"></div>`;
    }

    function fmt(seconds) {
        const n = Math.max(0, Math.floor(Number(seconds) || 0));
        return `${Math.floor(n / 60)}:${String(n % 60).padStart(2, '0')}`;
    }

    async function nui(name, data = {}) {
        if (!isFiveM) return { ok: true, preview: true };
        try {
            const res = await fetch(`https://${resourceName()}/${name}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(data),
            });
            try { return await res.json(); } catch { return { ok: true }; }
        } catch (e) {
            return { ok: false };
        }
    }

    function setClock() {
        const d = new Date();
        $('clock').textContent = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
    }

    function isStageOpen() {
        return $('stage')?.classList.contains('is-open');
    }

    function showStage() {
        const stage = $('stage');
        if (!stage) return;
        stage.hidden = false;
        stage.classList.add('is-open');
        document.body.classList.toggle('fivem', isFiveM);
        const bar = $('previewBar');
        if (bar) {
            const showPreview = !isFiveM;
            bar.hidden = !showPreview;
            bar.classList.toggle('is-open', showPreview);
        }
        setClock();
    }

    function hideStage() {
        const stage = $('stage');
        if (stage) {
            stage.hidden = true;
            stage.classList.remove('is-open');
        }
        const bar = $('previewBar');
        if (bar) {
            bar.hidden = true;
            bar.classList.remove('is-open');
        }
        $('modalRoot').innerHTML = '';
        state.mode = null;
        state.speaker = null;
    }

    function requestClose() {
        hideStage();
        nui('close');
    }

    function navItems() {
        if (state.mode === 'admin' || state.mode === 'create') {
            return [['admin', 'Booth Admin', icons.admin]];
        }
        if (state.mode === 'speaker') {
            return [
                ['speaker', 'Sound', icons.now],
                ['speakerMixer', 'Range', icons.mixer],
                ['speakerGroup', 'Group', icons.plus],
            ];
        }
        const items = [
            ['now', 'Now Playing', icons.now],
            ['queue', 'Queue', icons.queue],
            ['library', 'Library', icons.library],
            ['playlists', 'Playlists', icons.playlists],
            ['mixer', 'Mixer', icons.mixer],
        ];
        if (state.isAdmin) items.push(['admin', 'Booth Admin', icons.admin]);
        return items;
    }

    function trackCount(n) {
        return `${n} track${n === 1 ? '' : 's'}`;
    }

    function renderNav() {
        $('nav').innerHTML = navItems().map(([id, label, icon]) => (
            `<button class="${state.tab === id ? 'active' : ''}" data-tab="${id}">${icon}<span>${label}</span></button>`
        )).join('');
        $('nav').querySelectorAll('button').forEach((btn) => {
            btn.addEventListener('click', () => {
                if (btn.dataset.tab === 'admin' && state.mode !== 'admin' && state.mode !== 'create') {
                    nui('refreshAdmin');
                    return;
                }
                state.tab = btn.dataset.tab;
                render();
            });
        });
    }

    function renderChip() {
        $('appName').textContent = state.appName;
        $('appTag').textContent = state.appTagline;
        $('boothName').textContent = state.speaker?.label || state.booth?.name || (state.mode === 'admin' ? 'Placement' : 'No booth');
        if (state.speaker) {
            $('boothMeta').textContent = `${state.speaker.permanent ? 'Permanent' : 'Portable'} · ${Math.round(state.speaker.radius || 0)}m · group ${state.speaker.groupSize || 1}`;
            return;
        }
        const jobs = (state.booth?.jobs || []).map((j) => j.name || j).join(', ');
        $('boothMeta').textContent = state.booth
            ? `${jobs || 'Public'} · ${Math.round(state.playback.radius || state.booth.radius || 0)}m`
            : 'Use /djadmin to place a booth';
    }

    function composer() {
        return `
            <div class="composer">
                <input id="urlInput" placeholder="Paste a YouTube or HTTPS audio link" />
                <button class="btn btn-primary" id="playNow">Play now</button>
                <button class="btn btn-blue" id="queueNow">Queue</button>
                <button class="btn btn-ghost" id="saveNow">${icons.save} Save</button>
            </div>
        `;
    }

    function bindComposer() {
        const input = $('urlInput');
        if (!input) return;
        const send = (immediate) => {
            const url = input.value.trim();
            if (!url) return;
            nui('playUrl', { url, immediate });
            input.value = '';
        };
        $('playNow')?.addEventListener('click', () => send(true));
        $('queueNow')?.addEventListener('click', () => send(false));
        $('saveNow')?.addEventListener('click', () => {
            const url = input.value.trim() || state.playback.current?.url;
            if (!url) return;
            nui('saveSong', { url });
            input.value = '';
        });
        input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') send(false);
        });
    }

    function trackRow(track, index, kind) {
        const actions = [];
        if (kind === 'queue') {
            actions.push(`<button class="icon-btn" data-act="up" data-i="${index}">${icons.up}</button>`);
            actions.push(`<button class="icon-btn" data-act="down" data-i="${index}">${icons.down}</button>`);
            actions.push(`<button class="icon-btn" data-act="play" data-i="${index}">${icons.play}</button>`);
            actions.push(`<button class="icon-btn" data-act="remove" data-i="${index}">${icons.trash}</button>`);
        } else if (kind === 'library') {
            actions.push(`<button class="icon-btn" data-act="queue" data-id="${esc(track.id)}">${icons.plus}</button>`);
            actions.push(`<button class="icon-btn" data-act="play" data-id="${esc(track.id)}">${icons.play}</button>`);
            actions.push(`<button class="icon-btn" data-act="delete" data-id="${esc(track.id)}">${icons.trash}</button>`);
        } else if (kind === 'plist') {
            actions.push(`<button class="icon-btn" data-act="queue" data-i="${index}">${icons.plus}</button>`);
            actions.push(`<button class="icon-btn" data-act="remove" data-i="${index}">${icons.trash}</button>`);
        }
        return `
            <article class="track">
                ${cover(track)}
                <div>
                    <h4>${esc(track.title)}</h4>
                    <p>${esc(track.author || track.source || 'Track')} ${track.duration ? '· ' + fmt(track.duration) : ''}</p>
                </div>
                <div class="track-actions">${actions.join('')}</div>
            </article>
        `;
    }

    function renderNow() {
        const cur = state.playback.current;
        return `
            <div class="page-head">
                <div>
                    <p class="eyebrow">Session</p>
                    <h1>Now Playing</h1>
                    <p>Drop a YouTube link and run the room from this tablet.</p>
                </div>
            </div>
            <div class="hero">
                <div class="vinyl-wrap">
                    ${cover(cur || { title: 'Idle' })}
                    <div class="vinyl ${state.playback.playing && !state.playback.paused ? 'spin' : ''}"></div>
                </div>
                <div class="hero-copy">
                    <h2>${esc(cur?.title || 'Nothing in the air yet')}</h2>
                    <p class="author">${esc(cur?.author || 'Queue a track to start the night')}</p>
                    ${composer()}
                </div>
            </div>
            <div class="page-head"><h1 style="font-size:20px">Up next</h1></div>
            <div class="list" id="queueList">
                ${state.playback.queue.length ? state.playback.queue.slice(0, 6).map((t, i) => trackRow(t, i, 'queue')).join('') : `<div class="empty"><div class="blob"></div>Queue is clear.</div>`}
            </div>
        `;
    }

    function renderQueue() {
        return `
            <div class="page-head">
                <div>
                    <p class="eyebrow">Set list</p>
                    <h1>Queue</h1>
                    <p>${trackCount(state.playback.queue.length)} upcoming</p>
                </div>
                <button class="btn btn-danger" id="clearQueue">Clear</button>
            </div>
            ${composer()}
            <div class="list" style="margin-top:14px" id="queueList">
                ${state.playback.queue.length ? state.playback.queue.map((t, i) => trackRow(t, i, 'queue')).join('') : `<div class="empty"><div class="blob"></div>Nothing waiting. Paste a link above.</div>`}
            </div>
        `;
    }

    function renderLibrary() {
        return `
            <div class="page-head">
                <div>
                    <p class="eyebrow">Collection</p>
                    <h1>Saved songs</h1>
                    <p>Keep your go-to YouTube cuts on this tablet.</p>
                </div>
            </div>
            ${composer()}
            <div class="list" style="margin-top:14px" id="libraryList">
                ${state.songs.length ? state.songs.map((t) => trackRow(t, 0, 'library')).join('') : `<div class="empty"><div class="blob"></div>No saved songs yet. Play one, then hit Save.</div>`}
            </div>
        `;
    }

    function renderPlaylists() {
        if (state.selectedPlaylist) {
            const pl = state.playlists.find((p) => p.id === state.selectedPlaylist);
            if (!pl) {
                state.selectedPlaylist = null;
            } else {
                return `
                    <div class="page-head">
                        <div>
                            <p class="eyebrow">Playlist</p>
                            <h1>${esc(pl.name)}</h1>
                            <p>${trackCount(pl.tracks.length)}</p>
                        </div>
                        <div class="chips">
                            <button class="btn btn-ghost" id="backPlaylists">Back</button>
                            <button class="btn btn-blue" id="queuePlaylist">Add to queue</button>
                            <button class="btn btn-primary" id="playPlaylist">Play</button>
                        </div>
                    </div>
                    <div class="list" id="plistTracks">
                        ${pl.tracks.length ? pl.tracks.map((t, i) => trackRow(t, i, 'plist')).join('') : `<div class="empty"><div class="blob"></div>Add songs from your library.</div>`}
                    </div>
                    <div class="page-head"><h1 style="font-size:18px">Add from library</h1></div>
                    <div class="list" id="plistAdd">
                        ${state.songs.map((t) => `
                            <article class="track">
                                ${cover(t)}
                                <div><h4>${esc(t.title)}</h4><p>${esc(t.author || '')}</p></div>
                                <button class="btn btn-sm btn-ghost" data-add="${esc(t.id)}">Add</button>
                            </article>
                        `).join('') || '<div class="empty">Save songs first.</div>'}
                    </div>
                `;
            }
        }

        return `
            <div class="page-head">
                <div>
                    <p class="eyebrow">Sets</p>
                    <h1>Playlists</h1>
                    <p>Build a night in advance, then dump it into the booth.</p>
                </div>
                <button class="btn btn-primary" id="newPlaylist">${icons.plus} New playlist</button>
            </div>
            <div class="grid">
                ${state.playlists.map((p) => `
                    <article class="card">
                        ${cover(p.tracks[0] || { title: p.name })}
                        <h3>${esc(p.name)}</h3>
                        <p>${trackCount(p.tracks.length)}</p>
                        <div class="chips">
                            <button class="btn btn-sm btn-ghost" data-open="${esc(p.id)}">Open</button>
                            <button class="btn btn-sm btn-primary" data-play="${esc(p.id)}">Play</button>
                            <button class="btn btn-sm btn-danger" data-del="${esc(p.id)}">Delete</button>
                        </div>
                    </article>
                `).join('') || '<div class="empty span-2"><div class="blob"></div>Create your first playlist.</div>'}
            </div>
        `;
    }

    function renderMixer() {
        const vol = Math.round((state.playback.volume || 0) * 100);
        const radius = Math.round(state.playback.radius || 0);
        return `
            <div class="page-head">
                <div>
                    <p class="eyebrow">Room</p>
                    <h1>Mixer</h1>
                    <p>Shape how far the booth throws sound, and how the set repeats.</p>
                </div>
            </div>
            <div class="mixer">
                <article class="mixer-card">
                    <h3>Master volume</h3>
                    <div class="slider-row">
                        <input type="range" id="vol" min="0" max="${Math.round(state.limits.maxVolume * 100)}" value="${vol}" />
                        <span id="volLabel">${vol}%</span>
                    </div>
                </article>
                <article class="mixer-card">
                    <h3>Hearing radius</h3>
                    <div class="slider-row">
                        <input type="range" id="rad" min="${state.limits.minRadius}" max="${state.limits.maxRadius}" value="${radius}" />
                        <span id="radLabel">${radius}m</span>
                    </div>
                </article>
                <article class="mixer-card">
                    <h3>Loop</h3>
                    <div class="chips" id="loopChips">
                        ${['off', 'track', 'queue'].map((mode) => `<button class="chip ${state.playback.loop === mode ? 'on' : ''}" data-loop="${mode}">${mode}</button>`).join('')}
                    </div>
                </article>
                <article class="mixer-card">
                    <h3>Shuffle</h3>
                    <button class="chip ${state.playback.shuffle ? 'on' : ''}" id="shuffleBtn">${state.playback.shuffle ? 'On' : 'Off'}</button>
                </article>
            </div>
        `;
    }

    function renderSpeakerSound() {
        const cur = state.playback.current;
        const sp = state.speaker || {};
        return `
            <div class="page-head">
                <div>
                    <p class="eyebrow">${esc(sp.permanent ? 'Permanent rig' : 'Portable')}</p>
                    <h1>${esc(sp.label || 'Speaker')}</h1>
                    <p>Play a YouTube link from this speaker. Grouped speakers share the track.</p>
                </div>
            </div>
            <div class="hero">
                <div class="vinyl-wrap">
                    ${cover(cur || { title: sp.label || 'Speaker' })}
                    <div class="vinyl ${state.playback.playing && !state.playback.paused ? 'spin' : ''}"></div>
                </div>
                <div class="hero-copy">
                    <h2>${esc(cur?.title || 'Silent')}</h2>
                    <p class="author">${esc(cur?.author || 'Paste a link to fill the room')}</p>
                    ${composer()}
                </div>
            </div>
            <div class="page-head"><h1 style="font-size:20px">Up next</h1></div>
            <div class="list" id="queueList">
                ${state.playback.queue.length ? state.playback.queue.slice(0, 6).map((t, i) => trackRow(t, i, 'queue')).join('') : `<div class="empty"><div class="blob"></div>Queue is clear.</div>`}
            </div>
        `;
    }

    function renderSpeakerMixer() {
        const sp = state.speaker || {};
        const vol = Math.round((sp.volume || 0) * 100);
        const radius = Math.round(sp.radius || 0);
        return `
            <div class="page-head">
                <div>
                    <p class="eyebrow">Output</p>
                    <h1>Range & volume</h1>
                    <p>These sliders only change this speaker, not the rest of the group.</p>
                </div>
            </div>
            <div class="mixer">
                <article class="mixer-card">
                    <h3>Volume</h3>
                    <div class="slider-row">
                        <input type="range" id="vol" min="0" max="${Math.round(state.limits.maxVolume * 100)}" value="${vol}" />
                        <span id="volLabel">${vol}%</span>
                    </div>
                </article>
                <article class="mixer-card">
                    <h3>Hearing radius</h3>
                    <div class="slider-row">
                        <input type="range" id="rad" min="${state.limits.minRadius}" max="${state.limits.maxRadius}" value="${radius}" />
                        <span id="radLabel">${radius}m</span>
                    </div>
                </article>
                <article class="mixer-card">
                    <h3>Stay in the world</h3>
                    <button class="chip ${sp.permanent ? 'on' : ''}" id="permBtn" ${state.canPermanent ? '' : 'disabled'}>${sp.permanent ? 'Permanent' : 'Pick-upable'}</button>
                    <p style="margin-top:10px">Permanent speakers survive restarts and cannot be picked up until you unlock them.</p>
                </article>
                <article class="mixer-card">
                    <h3>Pickup</h3>
                    <button class="btn btn-danger" id="pickupBtn" ${state.canPickup ? '' : 'disabled'}>Pick up speaker</button>
                </article>
            </div>
        `;
    }

    function renderSpeakerGroup() {
        const nearby = state.nearby || [];
        return `
            <div class="page-head">
                <div>
                    <p class="eyebrow">Stack</p>
                    <h1>Group speakers</h1>
                    <p>Link nearby speakers so they play the same track in sync.</p>
                </div>
                <button class="btn btn-ghost" id="leaveGroup">Leave group</button>
            </div>
            <div class="list">
                ${nearby.length ? nearby.map((s) => `
                    <article class="track">
                        <div class="cover cover-fallback" style="--h:8"></div>
                        <div>
                            <h4>${esc(s.label)}</h4>
                            <p>${s.distance}m · ${s.grouped ? 'In this group' : 'Nearby'} ${s.permanent ? '· permanent' : ''}</p>
                        </div>
                        <div class="track-actions">
                            ${s.grouped
                                ? ''
                                : `<button class="btn btn-sm btn-primary" data-join="${esc(s.id)}">Group</button>`}
                        </div>
                    </article>
                `).join('') : '<div class="empty"><div class="blob"></div>No other speakers in range.</div>'}
            </div>
        `;
    }

    function jobText(booth) {
        const jobs = booth.jobs || [];
        if (!jobs.length) return 'Public';
        return jobs.map((j) => (j.grade ? `${j.name}:${j.grade}` : (j.name || j))).join(', ');
    }

    function renderAdmin() {
        return `
            <div class="page-head">
                <div>
                    <p class="eyebrow">Staff</p>
                    <h1>Booth admin</h1>
                    <p>Place desks in the world, lock them to jobs, and add extra speakers.</p>
                </div>
                <div class="admin-top">
                    <select class="select" id="modelSelect">
                        ${(state.models.length ? state.models : PREVIEW.models).map((m) => `<option value="${esc(m.model)}">${esc(m.label)}</option>`).join('')}
                    </select>
                    <button class="btn btn-primary" id="placeBooth">${icons.pin} Place booth</button>
                </div>
            </div>
            <div class="grid">
                ${state.booths.map((b) => `
                    <article class="card">
                        <p class="eyebrow">${esc(b.model || 'prop')}</p>
                        <h3>${esc(b.name)}</h3>
                        <p>${esc(jobText(b))} · ${Math.round(b.radius || 0)}m · ${(b.speakers || []).length} speakers</p>
                        <p>${b.coords ? `${b.coords.x.toFixed(1)}, ${b.coords.y.toFixed(1)}` : ''}</p>
                        <div class="chips">
                            <button class="btn btn-sm btn-ghost" data-edit="${esc(b.id)}">Edit</button>
                            <button class="btn btn-sm btn-blue" data-tp="${esc(b.id)}">Teleport</button>
                            <button class="btn btn-sm btn-mint" data-spk="${esc(b.id)}">Speaker</button>
                            <button class="btn btn-sm btn-danger" data-delb="${esc(b.id)}">Delete</button>
                        </div>
                    </article>
                `).join('') || '<div class="empty"><div class="blob"></div>No booths yet. Place one from this tablet.</div>'}
            </div>
        `;
    }

    function renderCreate() {
        const draft = state.draft || {};
        return `
            <div class="page-head">
                <div>
                    <p class="eyebrow">New booth</p>
                    <h1>Finish placement</h1>
                    <p>Name the booth and optionally lock it to jobs. Leave jobs blank for a public deck.</p>
                </div>
            </div>
            <div class="form-grid">
                <div class="field span-2">
                    <label>Booth name</label>
                    <input id="newName" value="${esc(draft.name || 'DJ Booth')}" />
                </div>
                <div class="field span-2">
                    <label>Jobs (comma separated, optional grade with job:grade)</label>
                    <input id="newJobs" placeholder="nightclub, unemployed:0" />
                </div>
                <div class="field">
                    <label>Radius (m)</label>
                    <input id="newRadius" type="number" min="8" max="120" value="${draft.radius || 40}" />
                </div>
                <div class="field">
                    <label>Default volume (0-1)</label>
                    <input id="newVolume" type="number" step="0.05" min="0.05" max="1" value="${draft.volume || 0.55}" />
                </div>
            </div>
            <div class="modal-actions">
                <button class="btn btn-ghost" id="cancelCreate">Cancel</button>
                <button class="btn btn-primary" id="confirmCreate">Create booth</button>
            </div>
        `;
    }

    function renderPlayer() {
        if (state.mode === 'admin' || state.mode === 'create') {
            $('player').innerHTML = `
                <div class="player-inner">
                    <div class="now-mini"><div class="cover cover-fallback" style="--h:210"></div><div><h4>Admin tablet</h4><p>Place booths anywhere in the city</p></div></div>
                    <div></div>
                    <div style="text-align:right"><button class="btn btn-ghost" id="closeUi">Close</button></div>
                </div>
            `;
            $('closeUi')?.addEventListener('click', requestClose);
            return;
        }

        const cur = state.playback.current;
        const pct = cur && state.playback.duration ? Math.min(100, (state.playback.elapsed / state.playback.duration) * 100) : 0;
        $('player').innerHTML = `
            <div class="player-inner">
                <div class="now-mini">
                    ${cover(cur || { title: 'Idle' })}
                    <div>
                        <h4>${esc(cur?.title || 'Idle')}</h4>
                        <p>${esc(cur?.author || 'Lumina')} · ${fmt(state.playback.elapsed)} / ${fmt(state.playback.duration)}</p>
                    </div>
                </div>
                <div class="transport">
                    <button class="icon-btn ${state.playback.shuffle ? 'active' : ''}" id="tShuffle">${icons.shuffle}</button>
                    <button class="icon-btn" id="tPrev">${icons.prev}</button>
                    <button class="play-main" id="tPlay">${state.playback.playing && !state.playback.paused ? icons.pause : icons.play}</button>
                    <button class="icon-btn" id="tNext">${icons.next}</button>
                    <button class="icon-btn ${state.playback.loop !== 'off' ? 'active' : ''}" id="tLoop">${icons.loop}</button>
                    <button class="icon-btn" id="tStop">${icons.stop}</button>
                </div>
                <div>
                    <div class="progress">
                        <span>${fmt(state.playback.elapsed)}</span>
                        <div class="bar" id="seekBar"><i style="width:${pct}%"></i></div>
                        <span>${fmt(state.playback.duration)}</span>
                    </div>
                    <div style="text-align:right;margin-top:8px"><button class="btn btn-ghost" id="closeUi">Close</button></div>
                </div>
            </div>
        `;

        $('tPlay')?.addEventListener('click', () => {
            if (!state.playback.current) return;
            nui('control', { action: state.playback.paused || !state.playback.playing ? 'resume' : 'pause' });
        });
        $('tPrev')?.addEventListener('click', () => nui('control', { action: 'previous' }));
        $('tNext')?.addEventListener('click', () => nui('control', { action: 'skip' }));
        $('tStop')?.addEventListener('click', () => nui('control', { action: 'stop' }));
        $('tShuffle')?.addEventListener('click', () => nui('control', { action: 'shuffle', value: !state.playback.shuffle }));
        $('tLoop')?.addEventListener('click', () => {
            const order = ['off', 'track', 'queue'];
            const next = order[(order.indexOf(state.playback.loop) + 1) % order.length];
            nui('control', { action: 'loop', value: next });
        });
        $('seekBar')?.addEventListener('click', (e) => {
            if (!state.playback.duration) return;
            const rect = e.currentTarget.getBoundingClientRect();
            const ratio = (e.clientX - rect.left) / rect.width;
            nui('control', { action: 'seek', value: Math.floor(ratio * state.playback.duration) });
        });
        $('closeUi')?.addEventListener('click', requestClose);
    }

    function bindPage() {
        bindComposer();

        $('clearQueue')?.addEventListener('click', () => nui('queue', { action: 'clear' }));
        $('queueList')?.addEventListener('click', (e) => {
            const btn = e.target.closest('button');
            if (!btn) return;
            const i = Number(btn.dataset.i);
            if (btn.dataset.act === 'remove') nui('queue', { action: 'remove', index: i + 1 });
            if (btn.dataset.act === 'play') nui('queue', { action: 'playIndex', index: i + 1 });
            if (btn.dataset.act === 'up') nui('queue', { action: 'move', from: i + 1, to: i });
            if (btn.dataset.act === 'down') nui('queue', { action: 'move', from: i + 1, to: i + 2 });
        });

        $('libraryList')?.addEventListener('click', (e) => {
            const btn = e.target.closest('button');
            if (!btn) return;
            const song = state.songs.find((s) => s.id === btn.dataset.id);
            if (btn.dataset.act === 'delete') nui('deleteSong', { id: btn.dataset.id });
            if (btn.dataset.act === 'queue' && song) nui('queue', { action: 'addTrack', track: song });
            if (btn.dataset.act === 'play' && song) nui('playUrl', { url: song.url, immediate: true });
        });

        $('newPlaylist')?.addEventListener('click', () => {
            openModal({
                title: 'New playlist',
                body: '<div class="field"><label>Name</label><input id="plName" placeholder="Friday Peak" /></div>',
                confirm: 'Create',
                onConfirm: () => nui('playlist', { action: 'create', name: document.getElementById('plName').value }),
            });
        });
        document.querySelectorAll('[data-open]').forEach((btn) => btn.addEventListener('click', () => {
            state.selectedPlaylist = btn.dataset.open;
            render();
        }));
        document.querySelectorAll('[data-play]').forEach((btn) => btn.addEventListener('click', () => nui('playlist', { action: 'play', id: btn.dataset.play })));
        document.querySelectorAll('[data-del]').forEach((btn) => btn.addEventListener('click', () => nui('playlist', { action: 'delete', id: btn.dataset.del })));
        $('backPlaylists')?.addEventListener('click', () => { state.selectedPlaylist = null; render(); });
        $('playPlaylist')?.addEventListener('click', () => nui('playlist', { action: 'play', id: state.selectedPlaylist }));
        $('queuePlaylist')?.addEventListener('click', () => nui('playlist', { action: 'queue', id: state.selectedPlaylist }));
        $('plistAdd')?.addEventListener('click', (e) => {
            const btn = e.target.closest('[data-add]');
            if (!btn) return;
            const track = state.songs.find((s) => s.id === btn.dataset.add);
            if (track) nui('playlist', { action: 'add', id: state.selectedPlaylist, track });
        });
        $('plistTracks')?.addEventListener('click', (e) => {
            const btn = e.target.closest('button');
            if (!btn) return;
            const pl = state.playlists.find((p) => p.id === state.selectedPlaylist);
            const i = Number(btn.dataset.i);
            if (btn.dataset.act === 'remove') nui('playlist', { action: 'remove', id: state.selectedPlaylist, index: i + 1 });
            if (btn.dataset.act === 'queue' && pl?.tracks[i]) nui('queue', { action: 'addTrack', track: pl.tracks[i] });
        });

        const vol = $('vol');
        vol?.addEventListener('input', () => { $('volLabel').textContent = `${vol.value}%`; });
        vol?.addEventListener('change', () => nui('control', { action: 'volume', value: Number(vol.value) / 100 }));
        const rad = $('rad');
        rad?.addEventListener('input', () => { $('radLabel').textContent = `${rad.value}m`; });
        rad?.addEventListener('change', () => nui('control', { action: 'radius', value: Number(rad.value) }));
        $('loopChips')?.addEventListener('click', (e) => {
            const btn = e.target.closest('[data-loop]');
            if (btn) nui('control', { action: 'loop', value: btn.dataset.loop });
        });
        $('shuffleBtn')?.addEventListener('click', () => nui('control', { action: 'shuffle', value: !state.playback.shuffle }));

        $('permBtn')?.addEventListener('click', () => nui('control', { action: 'permanent', value: !state.speaker?.permanent }));
        $('pickupBtn')?.addEventListener('click', () => nui('speakerPickup'));
        $('leaveGroup')?.addEventListener('click', () => nui('speakerGroup', { action: 'leave' }));
        document.querySelectorAll('[data-join]').forEach((btn) => {
            btn.addEventListener('click', () => nui('speakerGroup', { action: 'join', targetId: btn.dataset.join }));
        });

        $('placeBooth')?.addEventListener('click', () => nui('startPlacement', { model: $('modelSelect').value }));
        document.querySelectorAll('[data-tp]').forEach((btn) => {
            const booth = state.booths.find((b) => b.id === btn.dataset.tp);
            btn.addEventListener('click', () => nui('teleportBooth', { coords: booth?.coords }));
        });
        document.querySelectorAll('[data-delb]').forEach((btn) => btn.addEventListener('click', () => nui('deleteBooth', { id: btn.dataset.delb })));
        document.querySelectorAll('[data-spk]').forEach((btn) => btn.addEventListener('click', () => nui('startSpeakerPlacement', { boothId: btn.dataset.spk })));
        document.querySelectorAll('[data-edit]').forEach((btn) => btn.addEventListener('click', () => {
            const booth = state.booths.find((b) => b.id === btn.dataset.edit);
            if (!booth) return;
            openModal({
                title: 'Edit booth',
                body: `
                    <div class="field"><label>Name</label><input id="edName" value="${esc(booth.name)}" /></div>
                    <div class="field"><label>Jobs</label><input id="edJobs" value="${esc(jobText(booth) === 'Public' ? '' : jobText(booth))}" /></div>
                    <div class="field"><label>Radius</label><input id="edRad" type="number" value="${esc(booth.radius)}" /></div>
                    <div class="field"><label>Volume</label><input id="edVol" type="number" step="0.05" value="${esc(booth.volume || 0.55)}" /></div>
                `,
                confirm: 'Save',
                onConfirm: () => nui('updateBooth', {
                    id: booth.id,
                    name: document.getElementById('edName').value,
                    jobText: document.getElementById('edJobs').value,
                    radius: Number(document.getElementById('edRad').value),
                    volume: Number(document.getElementById('edVol').value),
                    model: booth.model,
                    coords: booth.coords,
                    heading: booth.heading,
                }),
            });
        }));

        $('cancelCreate')?.addEventListener('click', requestClose);
        $('confirmCreate')?.addEventListener('click', () => {
            nui('createBooth', {
                ...state.draft,
                name: $('newName').value,
                jobText: $('newJobs').value,
                radius: Number($('newRadius').value),
                volume: Number($('newVolume').value),
            });
        });
    }

    function openModal({ title, body, confirm, onConfirm }) {
        $('modalRoot').innerHTML = `
            <div class="modal">
                <h2>${esc(title)}</h2>
                ${body}
                <div class="modal-actions">
                    <button class="btn btn-ghost" id="modalCancel">Cancel</button>
                    <button class="btn btn-primary" id="modalOk">${esc(confirm || 'OK')}</button>
                </div>
            </div>
        `;
        $('modalCancel').addEventListener('click', () => { $('modalRoot').innerHTML = ''; });
        $('modalOk').addEventListener('click', () => {
            onConfirm?.();
            $('modalRoot').innerHTML = '';
        });
    }

    function render() {
        if (!isStageOpen()) return;
        if (state.mode === 'create') state.tab = 'create';
        if (state.mode === 'admin' && !['admin'].includes(state.tab)) state.tab = 'admin';
        if (state.mode === 'speaker' && !['speaker', 'speakerMixer', 'speakerGroup'].includes(state.tab)) state.tab = 'speaker';
        renderNav();
        renderChip();
        const page = $('page');
        const pages = {
            now: renderNow,
            queue: renderQueue,
            library: renderLibrary,
            playlists: renderPlaylists,
            mixer: renderMixer,
            speaker: renderSpeakerSound,
            speakerMixer: renderSpeakerMixer,
            speakerGroup: renderSpeakerGroup,
            admin: renderAdmin,
            create: renderCreate,
        };
        page.innerHTML = (pages[state.tab] || renderNow)();
        bindPage();
        renderPlayer();
    }

    function applySpeaker(payload) {
        state.mode = 'speaker';
        state.appName = payload.appName || 'Lumina';
        state.appTagline = payload.appTagline || 'Speaker';
        state.speaker = payload.speaker;
        state.playback = Object.assign(emptyPlayback(), payload.speaker?.state || payload.state || {});
        if (payload.speaker) {
            state.playback.volume = payload.speaker.volume ?? state.playback.volume;
            state.playback.radius = payload.speaker.radius ?? state.playback.radius;
        }
        state.nearby = payload.nearby || [];
        state.canPickup = !!payload.canPickup;
        state.canPermanent = !!payload.canPermanent;
        state.isAdmin = !!payload.isAdmin;
        state.limits = Object.assign(state.limits, payload.limits || {});
        if (!['speaker', 'speakerMixer', 'speakerGroup'].includes(state.tab)) state.tab = 'speaker';
        showStage();
        render();
    }

    function applyBoothPayload(payload) {
        state.mode = 'booth';
        state.appName = payload.appName || 'Lumina';
        state.appTagline = payload.appTagline || 'Live Booth OS';
        state.booth = payload.booth;
        state.speaker = null;
        state.playback = Object.assign(emptyPlayback(), payload.state || {});
        state.songs = payload.songs || [];
        state.playlists = payload.playlists || [];
        state.isAdmin = !!payload.isAdmin;
        state.playerName = payload.playerName || 'DJ';
        state.limits = Object.assign(state.limits, payload.limits || {});
        state.tab = 'now';
        showStage();
        render();
    }

    function applyAdmin(payload) {
        state.mode = 'admin';
        state.appName = payload.appName || 'Lumina';
        state.booths = payload.booths || [];
        state.models = payload.models || state.models;
        state.isAdmin = true;
        state.booth = null;
        state.tab = 'admin';
        showStage();
        render();
    }

    window.addEventListener('message', (event) => {
        const { action, payload } = event.data || {};
        if (action === 'openBooth') applyBoothPayload(payload || {});
        if (action === 'openSpeaker') applySpeaker(payload || {});
        if (action === 'syncSpeaker') {
            if (payload?.speaker) {
                state.speaker = payload.speaker;
                if (payload.speaker.state) {
                    state.playback = Object.assign(state.playback, payload.speaker.state);
                    state.playback.volume = payload.speaker.volume ?? state.playback.volume;
                    state.playback.radius = payload.speaker.radius ?? state.playback.radius;
                }
            }
            if (payload?.state) state.playback = Object.assign(state.playback, payload.state);
            if (payload?.nearby) state.nearby = payload.nearby;
            if (typeof payload?.canPickup === 'boolean') state.canPickup = payload.canPickup;
            render();
        }
        if (action === 'openAdmin') applyAdmin(payload || {});
        if (action === 'openCreate') {
            state.mode = 'create';
            state.draft = payload?.draft || {};
            state.models = payload?.models || state.models;
            state.appName = payload?.appName || 'Lumina';
            state.tab = 'create';
            showStage();
            render();
        }
        if (action === 'syncState') {
            if (payload?.booth) state.booth = payload.booth;
            if (payload?.state) state.playback = Object.assign(state.playback, payload.state);
            render();
        }
        if (action === 'syncLibrary') {
            state.songs = payload?.songs || state.songs;
            state.playlists = payload?.playlists || state.playlists;
            render();
        }
        if (action === 'progress') {
            state.playback.elapsed = payload.elapsed || 0;
            state.playback.duration = payload.duration || state.playback.duration;
            const bar = document.querySelector('#seekBar i');
            if (bar && state.playback.duration) {
                bar.style.width = `${Math.min(100, (state.playback.elapsed / state.playback.duration) * 100)}%`;
            }
        }
        if (action === 'close') hideStage();
    });

    document.addEventListener('keydown', (e) => {
        if (e.key !== 'Escape') return;
        e.preventDefault();
        if (isStageOpen()) hideStage();
        nui('close');
    });

    $('statusClose')?.addEventListener('click', requestClose);

    $('previewBar')?.addEventListener('click', (e) => {
        const btn = e.target.closest('button');
        if (!btn) return;
        $('previewBar').querySelectorAll('button').forEach((b) => b.classList.toggle('active', b === btn));
        if (btn.dataset.preview === 'booth') {
            applyBoothPayload({
                appName: 'Lumina',
                appTagline: 'Live Booth OS',
                booth: PREVIEW.booth,
                state: PREVIEW.playback,
                songs: PREVIEW.songs,
                playlists: PREVIEW.playlists,
                isAdmin: true,
                playerName: 'Diesel',
            });
        }
        if (btn.dataset.preview === 'admin') {
            applyAdmin({ appName: 'Lumina', booths: PREVIEW.booths, models: PREVIEW.models });
        }
        if (btn.dataset.preview === 'speaker') {
            applySpeaker({
                appName: 'Lumina',
                speaker: {
                    id: 'spk1',
                    label: 'Big Speaker',
                    item: 'lumina_speaker_big',
                    permanent: false,
                    volume: 0.7,
                    radius: 45,
                    groupSize: 2,
                    minRadius: 8,
                    maxRadius: 100,
                    state: PREVIEW.playback,
                },
                nearby: [
                    { id: 'spk2', label: 'Tripod Speaker', distance: 6, grouped: true, permanent: false },
                    { id: 'spk3', label: 'Handheld Speaker', distance: 12, grouped: false, permanent: false },
                ],
                canPickup: true,
                canPermanent: true,
                isAdmin: true,
            });
        }
        if (btn.dataset.preview === 'create') {
            state.mode = 'create';
            state.draft = { coords: { x: 1, y: 2, z: 3 }, heading: 90, model: 'prop_speaker_07' };
            state.tab = 'create';
            showStage();
            render();
        }
    });

    setInterval(setClock, 10000);

    document.querySelector('.home-bar')?.addEventListener('click', requestClose);

    if (isFiveM) {
        hideStage();
    } else {
        showStage();
        const view = new URLSearchParams(location.search).get('view') || 'booth';
        $('previewBar').querySelectorAll('button').forEach((b) => {
            b.classList.toggle('active', b.dataset.preview === view);
        });
        if (view === 'admin') {
            applyAdmin({ appName: 'Lumina', booths: PREVIEW.booths, models: PREVIEW.models });
        } else if (view === 'speaker' || view === 'speakerMixer' || view === 'speakerGroup') {
            applySpeaker({
                appName: 'Lumina',
                speaker: {
                    id: 'spk1',
                    label: 'Big Speaker',
                    item: 'lumina_speaker_big',
                    permanent: false,
                    volume: 0.7,
                    radius: 45,
                    groupSize: 2,
                    minRadius: 8,
                    maxRadius: 100,
                    state: PREVIEW.playback,
                },
                nearby: [
                    { id: 'spk2', label: 'Tripod Speaker', distance: 6, grouped: true, permanent: false },
                    { id: 'spk3', label: 'Handheld Speaker', distance: 12, grouped: false, permanent: false },
                ],
                canPickup: true,
                canPermanent: true,
                isAdmin: true,
            });
            if (view !== 'speaker') {
                state.tab = view;
                render();
            }
        } else if (view === 'create') {
            state.mode = 'create';
            state.draft = { coords: { x: 1, y: 2, z: 3 }, heading: 90, model: 'prop_speaker_07' };
            state.tab = 'create';
            showStage();
            render();
        } else {
            applyBoothPayload({
                appName: 'Lumina',
                appTagline: 'Live Booth OS',
                booth: PREVIEW.booth,
                state: PREVIEW.playback,
                songs: PREVIEW.songs,
                playlists: PREVIEW.playlists,
                isAdmin: true,
                playerName: 'Diesel',
            });
            if (view && view !== 'booth') state.tab = view;
            render();
        }
    }
})();
