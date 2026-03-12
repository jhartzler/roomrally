import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "roomrally-hacker-theme"

export default class extends Controller {
  static targets = ["indicator"]

  connect() {
    this.boundKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown)

    if (localStorage.getItem(STORAGE_KEY) === "on") {
      this.activate(false)
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  handleKeydown(e) {
    if (e.ctrlKey && e.shiftKey && e.key === "H") {
      e.preventDefault()
      this.toggle()
    }
  }

  toggle() {
    if (document.body.classList.contains("hacker-theme")) {
      this.deactivate()
    } else {
      this.activate(true)
    }
  }

  activate(withAnimation) {
    this.injectStyles()
    this.injectFont()

    if (withAnimation) {
      this.bootSequence()
    } else {
      document.body.classList.add("hacker-theme")
      this.updateIndicator(true)
    }

    localStorage.setItem(STORAGE_KEY, "on")
  }

  deactivate() {
    document.body.classList.remove("hacker-theme")
    this.updateIndicator(false)
    localStorage.setItem(STORAGE_KEY, "off")

    const overlay = document.getElementById("hacker-boot-overlay")
    if (overlay) overlay.remove()
  }

  updateIndicator(on) {
    if (!this.hasIndicatorTarget) return
    this.indicatorTarget.textContent = on ? "⬢ ACTIVE" : "ADMIN"
    this.indicatorTarget.className = on
      ? "text-xs font-semibold px-2 py-1 rounded-full hacker-indicator-on"
      : "text-xs font-semibold bg-red-100 text-red-700 px-2 py-1 rounded-full"
  }

  bootSequence() {
    const overlay = document.createElement("div")
    overlay.id = "hacker-boot-overlay"
    overlay.innerHTML = `<div class="hacker-boot-granted">ACCESS GRANTED</div>`
    document.body.appendChild(overlay)

    document.body.classList.add("hacker-theme")
    this.updateIndicator(true)

    setTimeout(() => {
      overlay.classList.add("hacker-boot-fade")
      setTimeout(() => overlay.remove(), 400)
    }, 600)
  }

  injectFont() {
    if (document.getElementById("hacker-font")) return
    const link = document.createElement("link")
    link.id = "hacker-font"
    link.rel = "stylesheet"
    link.href = "https://fonts.googleapis.com/css2?family=VT323&family=Share+Tech+Mono&display=swap"
    document.head.appendChild(link)
  }

  injectStyles() {
    if (document.getElementById("hacker-theme-styles")) return
    const style = document.createElement("style")
    style.id = "hacker-theme-styles"
    style.textContent = THEME_CSS
    document.head.appendChild(style)
  }
}

const THEME_CSS = `
/* ===== HACKER THEME ===== */

/* --- Boot sequence overlay --- */
#hacker-boot-overlay {
  position: fixed;
  inset: 0;
  z-index: 99999;
  background: #0a0a0a;
  display: flex;
  align-items: center;
  justify-content: center;
}
.hacker-boot-granted {
  color: #00ff41;
  font-size: 3rem;
  font-weight: bold;
  font-family: 'VT323', 'Courier New', monospace;
  opacity: 0;
  animation: hacker-granted 0.4s forwards;
  text-shadow: 0 0 20px rgba(0, 255, 65, 0.8), 0 0 40px rgba(0, 255, 65, 0.4);
  letter-spacing: 0.3em;
}
@keyframes hacker-granted {
  0% { opacity: 0; transform: scale(0.8); }
  60% { opacity: 1; transform: scale(1.05); }
  100% { opacity: 1; transform: scale(1); }
}
#hacker-boot-overlay.hacker-boot-fade {
  animation: hacker-fade-out 0.6s forwards;
}
@keyframes hacker-fade-out {
  to { opacity: 0; }
}

/* --- Main theme --- */
body.hacker-theme {
  background: #0a0a0a !important;
  color: #b0ffb0 !important;
  font-family: 'Share Tech Mono', 'Courier New', monospace !important;
}

/* CRT scanline overlay */
body.hacker-theme::after {
  content: '';
  position: fixed;
  inset: 0;
  pointer-events: none;
  z-index: 9998;
  background: repeating-linear-gradient(
    0deg,
    transparent,
    transparent 2px,
    rgba(0, 0, 0, 0.15) 2px,
    rgba(0, 0, 0, 0.15) 4px
  );
}

/* CRT vignette */
body.hacker-theme::before {
  content: '';
  position: fixed;
  inset: 0;
  pointer-events: none;
  z-index: 9997;
  background: radial-gradient(ellipse at center, transparent 60%, rgba(0, 0, 0, 0.5) 100%);
}

/* --- Header --- */
body.hacker-theme header {
  background: #0d0d0d !important;
  border-bottom-color: #00ff41 !important;
  box-shadow: 0 1px 0 rgba(0, 255, 65, 0.3), 0 4px 20px rgba(0, 255, 65, 0.05);
}

body.hacker-theme header a {
  color: #00ff41 !important;
  text-shadow: 0 0 8px rgba(0, 255, 65, 0.4);
  font-family: 'VT323', monospace !important;
  font-size: 1.3em;
  letter-spacing: 0.05em;
}

body.hacker-theme header nav a {
  font-size: 1.1em;
}

body.hacker-theme header nav a:hover {
  color: #7dffb3 !important;
  text-shadow: 0 0 12px rgba(0, 255, 65, 0.6);
}

body.hacker-theme header .text-gray-400 {
  color: #1a5c1a !important;
}

/* ADMIN badge → hacker indicator */
.hacker-indicator-on {
  background: rgba(0, 255, 65, 0.15) !important;
  color: #00ff41 !important;
  border: 1px solid rgba(0, 255, 65, 0.4);
  text-shadow: 0 0 6px rgba(0, 255, 65, 0.5);
  animation: hacker-pulse 2s ease-in-out infinite;
  font-family: 'VT323', monospace !important;
  font-size: 0.85rem;
  letter-spacing: 0.1em;
}
@keyframes hacker-pulse {
  0%, 100% { box-shadow: 0 0 4px rgba(0, 255, 65, 0.3); }
  50% { box-shadow: 0 0 12px rgba(0, 255, 65, 0.6); }
}

/* --- Main content --- */
body.hacker-theme main {
  position: relative;
  z-index: 1;
}

/* --- Headings --- */
body.hacker-theme h1,
body.hacker-theme h2 {
  color: #00ff41 !important;
  font-family: 'VT323', monospace !important;
  text-shadow: 0 0 10px rgba(0, 255, 65, 0.5);
  letter-spacing: 0.08em;
}
body.hacker-theme h1 { font-size: 2rem !important; }

/* --- Cards & containers --- */
body.hacker-theme .bg-white {
  background: #0d1117 !important;
  border-color: #1a3a1a !important;
  box-shadow: 0 0 8px rgba(0, 255, 65, 0.08), inset 0 1px 0 rgba(0, 255, 65, 0.05);
}
body.hacker-theme .bg-white:hover {
  border-color: #00ff41 !important;
  box-shadow: 0 0 15px rgba(0, 255, 65, 0.15), inset 0 1px 0 rgba(0, 255, 65, 0.1);
}

/* --- Text colors --- */
body.hacker-theme .text-gray-900,
body.hacker-theme .text-gray-700 {
  color: #c0ffc0 !important;
}
body.hacker-theme .text-gray-600,
body.hacker-theme .text-gray-500 {
  color: #5a8a5a !important;
}
body.hacker-theme .text-gray-400 {
  color: #3a6a3a !important;
}
body.hacker-theme .text-gray-300 {
  color: #2a5a2a !important;
}

/* --- Links --- */
body.hacker-theme .text-indigo-700,
body.hacker-theme a.text-indigo-700 {
  color: #00d4ff !important;
  text-shadow: 0 0 6px rgba(0, 212, 255, 0.3);
}
body.hacker-theme .text-indigo-700:hover,
body.hacker-theme a.text-indigo-700:hover {
  color: #7dffff !important;
  text-shadow: 0 0 12px rgba(0, 212, 255, 0.5);
}

/* --- Status dots --- */
body.hacker-theme .bg-green-500 {
  background: #00ff41 !important;
  box-shadow: 0 0 6px rgba(0, 255, 65, 0.6);
  animation: hacker-dot-glow 1.5s ease-in-out infinite;
}
body.hacker-theme .bg-red-500 {
  background: #ff3333 !important;
  box-shadow: 0 0 6px rgba(255, 51, 51, 0.6);
  animation: hacker-dot-glow-red 1.5s ease-in-out infinite;
}
body.hacker-theme .bg-amber-500 {
  background: #ffaa00 !important;
  box-shadow: 0 0 6px rgba(255, 170, 0, 0.6);
}
body.hacker-theme .bg-gray-400 {
  background: #3a6a3a !important;
}
@keyframes hacker-dot-glow {
  0%, 100% { box-shadow: 0 0 4px rgba(0, 255, 65, 0.4); }
  50% { box-shadow: 0 0 10px rgba(0, 255, 65, 0.8); }
}
@keyframes hacker-dot-glow-red {
  0%, 100% { box-shadow: 0 0 4px rgba(255, 51, 51, 0.4); }
  50% { box-shadow: 0 0 10px rgba(255, 51, 51, 0.8); }
}

/* --- Badges / flags --- */
body.hacker-theme .bg-red-100 {
  background: rgba(255, 51, 51, 0.15) !important;
}
body.hacker-theme .text-red-800,
body.hacker-theme .text-red-700 {
  color: #ff5555 !important;
}
body.hacker-theme .text-red-600 {
  color: #ff4444 !important;
  text-shadow: 0 0 4px rgba(255, 68, 68, 0.3);
}
body.hacker-theme .bg-amber-100 {
  background: rgba(255, 170, 0, 0.15) !important;
}
body.hacker-theme .text-amber-800 {
  color: #ffbb33 !important;
}
body.hacker-theme .bg-green-100 {
  background: rgba(0, 255, 65, 0.1) !important;
}
body.hacker-theme .text-green-800 {
  color: #00ff41 !important;
}
body.hacker-theme .bg-green-600 {
  background: #0a5a0a !important;
  border: 1px solid #00ff41;
}

/* --- Buttons --- */
body.hacker-theme button:not([disabled]):hover {
  text-shadow: 0 0 6px rgba(0, 255, 65, 0.4);
}

/* Orange buttons (AI reset, etc.) */
body.hacker-theme .bg-orange-100 {
  background: rgba(255, 170, 0, 0.1) !important;
}
body.hacker-theme .text-orange-700,
body.hacker-theme .text-orange-600 {
  color: #ffaa00 !important;
}
body.hacker-theme .bg-orange-100:hover,
body.hacker-theme .hover\\:bg-orange-200:hover {
  background: rgba(255, 170, 0, 0.2) !important;
}

/* Red action buttons */
body.hacker-theme .bg-red-500 {
  background: rgba(255, 51, 51, 0.8) !important;
}

/* --- Hide button column --- */
body.hacker-theme .border-l {
  border-left-color: #1a3a1a !important;
}
body.hacker-theme .hover\\:bg-gray-50:hover {
  background: rgba(0, 255, 65, 0.05) !important;
}

/* --- Checkbox --- */
body.hacker-theme input[type="checkbox"] {
  accent-color: #00ff41;
}
body.hacker-theme label {
  color: #5a8a5a !important;
}

/* --- Timeline --- */
body.hacker-theme .font-mono {
  color: #7dffb3 !important;
}

/* --- Session detail grid values --- */
body.hacker-theme .text-2xl {
  color: #00ff41 !important;
  text-shadow: 0 0 8px rgba(0, 255, 65, 0.3);
  font-family: 'VT323', monospace !important;
}

/* --- Arrow indicator --- */
body.hacker-theme .text-lg {
  color: #1a5c1a !important;
}
body.hacker-theme .bg-white:hover .text-lg {
  color: #00ff41 !important;
}

/* --- Borders --- */
body.hacker-theme .border-gray-200 {
  border-color: #1a3a1a !important;
}
body.hacker-theme .border-b {
  border-bottom-color: #1a3a1a !important;
}

/* --- Shadows override --- */
body.hacker-theme .shadow-sm {
  box-shadow: 0 0 8px rgba(0, 255, 65, 0.06) !important;
}
body.hacker-theme .shadow-lg {
  box-shadow: 0 0 20px rgba(0, 255, 65, 0.15) !important;
}

/* --- Flash messages --- */
body.hacker-theme #flash > div {
  background: #0d1117 !important;
  border: 1px solid #00ff41;
  color: #00ff41 !important;
  text-shadow: 0 0 4px rgba(0, 255, 65, 0.3);
}

/* --- Scrollbar --- */
body.hacker-theme::-webkit-scrollbar {
  width: 8px;
}
body.hacker-theme::-webkit-scrollbar-track {
  background: #0a0a0a;
}
body.hacker-theme::-webkit-scrollbar-thumb {
  background: #1a3a1a;
  border-radius: 4px;
}
body.hacker-theme::-webkit-scrollbar-thumb:hover {
  background: #00ff41;
}

/* --- Selection --- */
body.hacker-theme ::selection {
  background: rgba(0, 255, 65, 0.3);
  color: #fff;
}

/* --- Subtle ambient flicker on header title --- */
body.hacker-theme header > div > a:first-child {
  animation: hacker-flicker 4s linear infinite;
}
@keyframes hacker-flicker {
  0%, 97%, 100% { opacity: 1; }
  97.5% { opacity: 0.85; }
  98% { opacity: 1; }
  98.5% { opacity: 0.9; }
}
`
