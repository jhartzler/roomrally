export default function confetti(options = {}) {
  // Respect user preference for reduced motion
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    return;
  }

  const {
    count = 80,
    zIndex = 9999,
    duration = 3500,
    colors = ["#60a5fa", "#34d399", "#fbbf24", "#f87171", "#a78bfa", "#fb923c"]
  } = options;

  const container = document.createElement("div");
  container.style.cssText = `
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
    z-index: ${zIndex};
  `;

  for (let i = 0; i < count; i++) {
    const confetti = document.createElement("div");
    const color = colors[Math.floor(Math.random() * colors.length)];
    const left = Math.random() * 100;
    const delay = Math.random() * 0.5;
    const fallDuration = 2 + Math.random() * 1;

    confetti.style.cssText = `
      position: absolute;
      width: ${Math.random() * 10 + 5}px;
      height: ${Math.random() * 10 + 5}px;
      background: ${color};
      left: ${left}%;
      top: -10%;
      opacity: 1;
      animation: confetti-fall ${fallDuration}s linear ${delay}s forwards;
    `;

    container.appendChild(confetti);
  }

  document.body.appendChild(container);

  // Remove after animation completes
  setTimeout(() => {
    container.remove();
  }, duration);
}
