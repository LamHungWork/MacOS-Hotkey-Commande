import Foundation

/// The page a phone opens. It holds the buttons it was sent with, so they show at once, then asks for
/// changes every two seconds.
enum PhonePage {
    static func html(base: String, state: Data) -> Data {
        let json = String(decoding: state, as: UTF8.self).replacingOccurrences(of: "<", with: "\\u003c")
        return Data(template
            .replacingOccurrences(of: "{{base}}", with: base)
            .replacingOccurrences(of: "{{state}}", with: json).utf8)
    }

    static func manifest(base: String) -> Data {
        return Data("""
            {"name":"Hotkey Commander","short_name":"Hotkey Commander","start_url":"\(base)/","scope":"\(base)/",\
            "display":"standalone","background_color":"#0E0F12","theme_color":"#0E0F12",\
            "icons":[{"src":"\(base)/app-icon.png","sizes":"512x512","type":"image/png"}]}
            """.utf8)
    }

    private static let template = #"""
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <title>Hotkey Commander</title>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">
        <meta name="apple-mobile-web-app-capable" content="yes">
        <meta name="mobile-web-app-capable" content="yes">
        <meta name="apple-mobile-web-app-title" content="Hotkey Commander">
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
        <meta name="format-detection" content="telephone=no">
        <meta name="theme-color" content="#0E0F12">
        <link rel="icon" href="{{base}}/app-icon.png">
        <link rel="apple-touch-icon" href="{{base}}/app-icon.png">
        <link rel="manifest" href="{{base}}/manifest.webmanifest">
        <style>
        * {
          box-sizing: border-box;
          -webkit-user-select: none; user-select: none;
          -webkit-touch-callout: none;
          -webkit-tap-highlight-color: transparent;
          touch-action: pan-y;
        }
        [hidden] { display: none !important; }
        html { background: #0E0F12; -webkit-text-size-adjust: 100%; overscroll-behavior: none; }
        body {
          display: flex; flex-direction: column; margin: 0; min-height: 100vh; min-height: 100dvh;
          color: #F4F5F7; font-family: -apple-system, system-ui, sans-serif;
        }
        body:not(.scrolls) { height: 100vh; height: 100dvh; overflow: hidden; }
        #safe {
          position: fixed; visibility: hidden;
          padding: env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left);
        }

        header {
          flex: none; display: flex; align-items: center; justify-content: space-between; gap: 16px;
          height: 32px; margin: max(8px, env(safe-area-inset-top)) 0 10px;
          padding: 0 calc(24px + env(safe-area-inset-right)) 0 calc(24px + env(safe-area-inset-left));
          color: #A9AFBB; font-size: 13px; line-height: 18px;
        }
        #mac { font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        #status { flex: none; display: flex; align-items: center; gap: 7px; }
        #dot { width: 8px; height: 8px; border-radius: 50%; background: #4ADE80; }
        .lost #status { color: #F2C46D; }
        .lost #dot { background: #F2B33D; }

        main { flex: 1; display: flex; align-items: center; justify-content: center; }
        .scrolls main { align-items: flex-start; }
        #grid { display: grid; grid-template-columns: repeat(var(--columns), var(--tile)); gap: var(--gap); }
        .lost #grid { opacity: 0.32; }
        button {
          position: relative; display: flex; align-items: center; justify-content: center;
          width: var(--tile); height: var(--tile); margin: 0; padding: 0 calc(var(--tile) * 0.09);
          border: 1px solid #3A3D46; border-radius: calc(var(--tile) * 0.225);
          background: #1E2026; color: #FFFFFF; font: inherit; text-align: center; appearance: none; -webkit-appearance: none;
          transition: transform 120ms ease-out, background 120ms ease-out;
        }
        button.icon { border-color: transparent; }
        button img, button.icon::after {
          position: absolute; inset: -1px; width: calc(100% + 2px); height: calc(100% + 2px);
          border-radius: calc(var(--tile) * 0.225); pointer-events: none;
        }
        button img { object-fit: cover; }
        button.icon::after { content: ''; background: #FFFFFF; opacity: 0; transition: opacity 120ms ease-out; }
        button.down { transform: scale(0.94); background: #33363F; }
        button.icon.down::after { opacity: 0.16; }
        button span { pointer-events: none; }
        .name {
          width: 100%; max-height: 100%; overflow: hidden; overflow-wrap: anywhere;
          display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 3;
          font-size: clamp(13px, calc(var(--tile) * 0.1125), 28px); line-height: 1.28; font-weight: 600;
        }
        .key { font-size: calc(var(--tile) * 0.357); line-height: 1.2; font-weight: 600; }
        .ring {
          position: absolute; inset: -3px; border: 3px solid #D5D8DF; border-radius: calc(var(--tile) * 0.225 + 2px);
          animation: received 520ms ease-out forwards;
        }
        @keyframes received { from { opacity: 1; transform: scale(1); } to { opacity: 0; transform: scale(1.08); } }
        @media (prefers-reduced-motion: reduce) {
          @keyframes received { from { opacity: 1; } to { opacity: 0; } }
          button.down { transform: none; }
        }

        #card {
          position: fixed; left: 0; right: 0; bottom: max(14px, env(safe-area-inset-bottom)); z-index: 1;
          display: flex; align-items: center; gap: 16px; width: calc(100% - 46px); max-width: 440px; margin: 0 auto; padding: 20px;
          border: 1px solid #3A3D45; border-radius: 28px; background: #1C1E23;
        }
        #card > span:first-child {
          flex: none; display: flex; align-items: center; justify-content: center;
          width: 52px; height: 52px; border-radius: 16px; background: #3A2F16; color: #F2B33D;
        }
        #card b { display: block; font-size: 18px; line-height: 23px; font-weight: 700; }
        #card small { display: block; margin-top: 3px; font-size: 14px; line-height: 19px; color: #B4B9C4; }

        .note {
          flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 22px; text-align: center;
          padding: max(16px, env(safe-area-inset-top)) calc(36px + env(safe-area-inset-right))
            max(16px, env(safe-area-inset-bottom)) calc(36px + env(safe-area-inset-left));
        }
        .note > span {
          display: flex; align-items: center; justify-content: center;
          width: 96px; height: 96px; border-radius: 28px; background: #1C1E23; color: #8AB4FF;
        }
        .note b { display: block; font-size: 22px; line-height: 28px; font-weight: 700; }
        .note small { display: block; max-width: 420px; margin-top: 8px; font-size: 15px; line-height: 21px; color: #B4B9C4; }
        svg { fill: none; stroke: currentColor; stroke-linecap: round; stroke-linejoin: round; }

        @media (orientation: landscape) {
          header { position: fixed; z-index: 1; top: 25px; right: var(--dot, 26px); height: auto; margin: 0; padding: 0; }
          #mac, #word { display: none; }
        }
        </style>
        </head>
        <body>
        <div id="safe"></div>
        <header id="header">
          <span id="mac"></span>
          <span id="status"><span id="dot"></span><span id="word"></span></span>
        </header>
        <main id="main"><div id="grid"></div></main>
        <div id="card" hidden>
          <span><svg width="28" height="28" viewBox="0 0 24 24" stroke-width="1.8"><path d="M4 4l16 16M2.8 9.2a13.5 13.5 0 0 1 4-2.6M10.5 5.3A13.6 13.6 0 0 1 21.2 9.2M6.2 12.9a8.6 8.6 0 0 1 3.4-2M14.6 11.2a8.6 8.6 0 0 1 3.2 1.7M9.6 16.4a3.8 3.8 0 0 1 4.8 0M12 19.5v.1"/></svg></span>
          <span><b>Can't reach Mac</b><small>Check that both are on the same Wi-Fi.</small></span>
        </div>
        <section id="removed" class="note" hidden>
          <span><svg width="50" height="50" viewBox="0 0 24 24" stroke-width="1.6"><path d="M4 4h6v6H4ZM14 4h6v6h-6ZM4 14h6v6H4ZM14 14h2.5v2.5H14ZM20 14v.1M17.5 17.5H20V20M14 20v.1"/></svg></span>
          <div><b>Scan the code on your Mac again.</b><small>This phone was removed. On your Mac, open Configure…, Phone, then Add device…</small></div>
        </section>
        <section id="empty" class="note" hidden>
          <span><svg width="50" height="50" viewBox="0 0 24 24" stroke-width="1.6"><path d="M4 4h7v7H4ZM13 4h7v7h-7ZM4 13h7v7H4ZM16.5 13.5v6M13.5 16.5h6"/></svg></span>
          <div><b>Add buttons on your Mac</b><small>They show up here by themselves.</small></div>
        </section>
        <script type="application/json" id="state">{{state}}</script>
        <script>
        (() => {
          const base = '{{base}}';
          const part = (id) => document.getElementById(id);
          const grid = part('grid');
          const touches = new Map();
          const noIcon = new Set(); // buttons whose icon did not load
          let buttons = [];
          let version = '';
          let clock = 0; // what to add to this phone's clock to get the Mac's
          let answered = { wall: 0, steady: 0 }; // when the Mac last answered, on both of this phone's clocks
          let problem = ''; // '', 'lost' or 'removed'
          let shownUntil = 0; // how long a problem stays on screen at least
          let question = null; // the one the Mac is being asked now

          // ---- What shows

          function show() {
            document.body.classList.toggle('lost', problem === 'lost');
            part('word').textContent = problem === 'lost' ? 'Reconnecting…' : 'Connected';
            part('header').hidden = problem === 'removed';
            part('main').hidden = problem === 'removed' || buttons.length === 0;
            part('card').hidden = problem !== 'lost';
            part('removed').hidden = problem !== 'removed';
            part('empty').hidden = problem !== '' || buttons.length > 0;
          }

          function setProblem(next) {
            if (next === '' && performance.now() < shownUntil) return;
            const back = problem !== '' && next === '';
            problem = next;
            if (back && noIcon.size > 0) {
              noIcon.clear(); // it may have been the connection
              draw();
            }
            show();
          }

          // The fewest columns that fit every button, 72 px or more, with margins and gaps of 14 to 24 px.
          // Nothing fits: as many columns as 72 px allows, and the page scrolls.
          function layout() {
            const count = buttons.length;
            if (count === 0) return;
            const safe = getComputedStyle(part('safe'));
            const inset = (side) => parseFloat(safe['padding' + side]) || 0;
            const portrait = matchMedia('(orientation: portrait)').matches;
            const wide = document.documentElement.clientWidth - inset('Left') - inset('Right');
            const top = (gap) => portrait ? Math.max(8, inset('Top')) + 42 : Math.max(inset('Top'), gap);
            const bottom = (gap) => Math.max(inset('Bottom'), gap);
            const tileFor = (columns, gap) => Math.floor((wide - (columns + 1) * gap) / columns);
            const highFor = (gap) => innerHeight - top(gap) - bottom(gap);

            let fit = null;
            for (let columns = 1; columns <= count && !fit; columns += 1) {
              const rows = Math.ceil(count / columns);
              for (let gap = 14; gap <= 24 && !fit; gap += 0.5) {
                const tile = tileFor(columns, gap);
                if (tile >= 72 && rows * tile + (rows - 1) * gap <= highFor(gap)) fit = { columns, gap, tile };
              }
            }
            if (!fit) {
              // One row, as high as the space there is.
              const tile = Math.min(tileFor(count, 14), Math.floor(highFor(14)));
              if (tile >= 72) fit = { columns: count, gap: 14, tile };
            }
            const scrolls = !fit;
            if (!fit) {
              const columns = Math.max(1, Math.floor((wide - 14) / 86));
              fit = { columns, gap: 14, tile: tileFor(columns, 14) };
            }

            const side = inset('Right') + (wide - fit.columns * fit.tile - (fit.columns - 1) * fit.gap) / 2;
            const style = document.documentElement.style;
            style.setProperty('--columns', fit.columns);
            style.setProperty('--gap', fit.gap + 'px');
            style.setProperty('--tile', fit.tile + 'px');
            // Landscape has no header, only the dot: in the margin, never on a button.
            style.setProperty('--dot', Math.max(3, Math.min(26, (side - 8) / 2)) + 'px');
            const main = part('main').style;
            main.padding = `${portrait ? 0 : top(fit.gap)}px ${inset('Right')}px ${bottom(fit.gap)}px ${inset('Left')}px`;
            document.body.classList.toggle('scrolls', scrolls);
          }

          function element(tag, className, text) {
            const node = document.createElement(tag);
            node.className = className;
            if (text) node.textContent = text;
            return node;
          }

          function face(button) {
            const node = element('button', '');
            node.type = 'button';
            node.dataset.id = button.id;
            node.setAttribute('aria-label', button.name || button.key);
            if (button.icon && !noIcon.has(button.id)) {
              const image = element('img', '');
              image.alt = '';
              image.draggable = false;
              image.onerror = () => {
                noIcon.add(button.id);
                node.replaceWith(face(button));
              };
              image.src = base + '/icon/' + button.icon;
              node.classList.add('icon');
              node.append(image);
            } else {
              node.append(button.name ? element('span', 'name', button.name) : element('span', 'key', button.key));
            }
            return node;
          }

          function draw() {
            grid.replaceChildren(...buttons.map(face));
            layout();
          }

          function take(state) {
            clock = state.now - performance.now();
            answered = { wall: Date.now(), steady: performance.now() };
            version = state.v;
            if (state.buttons) {
              part('mac').textContent = state.mac[0];
              buttons = state.buttons;
              noIcon.clear();
              draw();
            }
          }

          // ---- The Mac

          async function ask(path, method, limit) {
            const stop = new AbortController();
            const timer = setTimeout(() => stop.abort(), limit);
            try {
              const answer = await fetch(base + path, { method, cache: 'no-store', signal: stop.signal });
              return { status: answer.status, text: await answer.text() };
            } finally {
              clearTimeout(timer);
            }
          }

          // Several callers share one question. One from before the phone slept is given up for a new one.
          function refresh() {
            if (question && Date.now() - question.wall < 3000) return question.done;
            const mine = { wall: Date.now() };
            question = mine;
            mine.done = (async () => {
              let next = 'lost';
              try {
                const answer = await ask('/state?v=' + encodeURIComponent(version), 'GET', 3000);
                if (question !== mine) return;
                if (answer.status === 200) {
                  take(JSON.parse(answer.text));
                  next = '';
                } else if (answer.status === 404) {
                  next = 'removed';
                }
              } catch (error) {
                if (question !== mine) return;
              }
              question = null;
              setProblem(next);
            })();
            return mine.done;
          }

          // While a phone sleeps its steady clock may stop and nothing is asked, so the Mac's time is not known.
          function knowsClock() {
            const wall = Date.now() - answered.wall;
            return wall >= 0 && wall < 6000 && Math.abs(wall - (performance.now() - answered.steady)) < 1000;
          }

          // Runs within 3 seconds of the touch, or says that it did not.
          async function run(id) {
            const touched = performance.now();
            const left = () => 3000 - (performance.now() - touched);
            if (!knowsClock()) {
              await Promise.race([refresh(), new Promise((done) => setTimeout(done, 3000))]);
              if (problem === 'removed') return;
              if (!knowsClock() || problem !== '' || left() <= 0) return notSent();
            }
            try {
              const answer = await ask('/run/' + id + '?at=' + Math.round(touched + clock), 'POST', left());
              if (answer.status === 204) return flash(id);
            } catch (error) {
              return notSent();
            }
            await refresh();
            // Refused, though the phone and the button are still known: it came too late.
            if (problem === '' && buttons.some((button) => button.id === id)) notSent();
          }

          function notSent() {
            shownUntil = performance.now() + 2000;
            setProblem('lost');
          }

          // The Mac has the touch. What the script does is not known here.
          function flash(id) {
            const node = [...grid.children].find((child) => child.dataset.id === id);
            if (!node) return;
            node.querySelector('.ring')?.remove();
            const ring = element('span', 'ring');
            ring.addEventListener('animationend', () => ring.remove());
            node.append(ring);
          }

          // ---- Touches

          function drop(pointer) {
            const touch = touches.get(pointer);
            if (!touch) return null;
            touches.delete(pointer);
            setTimeout(() => touch.node.classList.remove('down'), 120);
            return touch;
          }

          grid.addEventListener('pointerdown', (event) => {
            const node = event.target.closest('button');
            if (!node || problem !== '' || event.button !== 0) return;
            touches.set(event.pointerId, { node, id: node.dataset.id, x: event.clientX, y: event.clientY });
            node.classList.add('down');
          });
          addEventListener('pointermove', (event) => {
            const touch = touches.get(event.pointerId);
            if (touch && Math.hypot(event.clientX - touch.x, event.clientY - touch.y) > 10) drop(event.pointerId);
          });
          addEventListener('pointercancel', (event) => drop(event.pointerId));
          addEventListener('pointerup', (event) => {
            const touch = drop(event.pointerId);
            if (touch && problem === '') run(touch.id);
          });
          for (const name of ['contextmenu', 'selectstart', 'dblclick', 'gesturestart']) {
            addEventListener(name, (event) => event.preventDefault(), { passive: false });
          }
          addEventListener('resize', layout);
          document.addEventListener('visibilitychange', () => {
            if (!document.hidden) refresh();
          });

          take(JSON.parse(part('state').textContent));
          answered = { wall: 0, steady: 0 }; // the page took an unknown time to get here
          show();
          layout();
          refresh();
          setInterval(refresh, 2000);
        })();
        </script>
        </body>
        </html>
        """#
}
