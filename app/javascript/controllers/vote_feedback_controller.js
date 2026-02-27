import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    vote(event) {
        const button = event.currentTarget
        const votedCard = this.element
        const allCards = Array.from(document.querySelectorAll('.response-card'))
        const otherCards = allCards.filter(c => c !== votedCard)

        // Haptic feedback (mobile only)
        if (navigator.vibrate) {
            navigator.vibrate(50)
        }

        // Animate unchosen cards falling away
        otherCards.forEach((card, i) => {
            const rotation = i % 2 === 0 ? -4 : 4
            card.style.transition = 'transform 400ms ease-in, opacity 350ms ease-in'
            card.style.transform = `translateY(70px) rotate(${rotation}deg)`
            card.style.opacity = '0'
            card.style.pointerEvents = 'none'
        })

        // After fall-away, replace the vote button with a checkmark and highlight the voted card
        setTimeout(() => {
            const form = votedCard.querySelector('form')
            if (form) {
                const checkmark = document.createElement('div')
                checkmark.className = 'flex items-center justify-center gap-2 py-1 animate-bounce-in'
                checkmark.innerHTML = `
                    <svg class="w-6 h-6 text-green-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/>
                    </svg>
                    <span class="text-green-400 font-black text-base">Vote cast!</span>
                `
                form.replaceWith(checkmark)
            }
            votedCard.style.transition = 'transform 300ms ease-out, border-color 300ms'
            votedCard.style.transform = 'scale(1.03)'
            votedCard.style.borderColor = 'rgba(74, 222, 128, 0.5)'
        }, 320)

        // Defer button disable so form activation behavior fires first.
        // (Disabling synchronously in a click handler blocks form submission —
        //  the browser checks disabled state after handlers run.)
        setTimeout(() => {
            document.querySelectorAll('button[data-action*="vote-feedback#vote"]').forEach(btn => {
                btn.disabled = true
                btn.classList.add('opacity-75', 'cursor-not-allowed')
            })
        }, 0)
    }
}
