import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit() {
    const startDateInput = this.element.querySelector('input[name="start_date"]')
    if (startDateInput) {
      const url = new URL(window.location.href)
      startDateInput.value = url.searchParams.get("start_date") || ""
    }

    const input = this.element.querySelector("#ai_chat_input")
    if (!input || !input.value.trim()) return

    const messages = document.getElementById("ai_chat_messages")
    if (!messages) return

    const text = this.normalizeUserMessage(input.value)

    const userBubble = document.createElement("div")
    userBubble.id = "ai_chat_user_pending"
    userBubble.className = "flex items-start justify-end ai-chat-pop"
    userBubble.innerHTML = `
      <div class="self-start inline-flex flex-col max-w-[80%] rounded-2xl px-4 py-3 text-sm leading-relaxed"
           style="background-color: color-mix(in srgb, var(--studs-accent) 15%, transparent); border: 1px solid color-mix(in srgb, var(--studs-accent) 30%, transparent); color: #f0fdf4;">
        <div class="mb-1.5">
          <span class="text-[10px] font-bold uppercase tracking-widest"
                style="color: var(--studs-accent);">You</span>
        </div>
        <div class="whitespace-pre-wrap break-words">${text.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;")}</div>
      </div>
    `
    messages.appendChild(userBubble)

    // Show thinking dots
    const thinking = document.createElement("div")
    thinking.id = "ai_chat_thinking"
    thinking.className = "flex items-start justify-start ai-chat-pop"
    thinking.innerHTML = `
      <div class="self-start inline-flex flex-col max-w-[80%] rounded-2xl px-4 py-3 text-sm leading-relaxed"
           style="background-color: var(--studs-panel-bg-2); border: 1px solid var(--studs-border); color: #f4f4f5;">
        <div class="mb-1.5">
          <span class="text-[10px] font-bold uppercase tracking-widest"
                style="color: color-mix(in srgb, var(--studs-accent) 60%, #a1a1aa);">Assistant</span>
        </div>
        <div class="flex items-center gap-1 py-1">
          <span class="h-2 w-2 rounded-full animate-bounce" style="background-color: var(--studs-accent); opacity: 0.7; animation-delay: 0ms"></span>
          <span class="h-2 w-2 rounded-full animate-bounce" style="background-color: var(--studs-accent); opacity: 0.7; animation-delay: 150ms"></span>
          <span class="h-2 w-2 rounded-full animate-bounce" style="background-color: var(--studs-accent); opacity: 0.7; animation-delay: 300ms"></span>
        </div>
      </div>
    `
    messages.appendChild(thinking)
    messages.scrollTop = messages.scrollHeight

    // Clear the input immediately so it doesn't show alongside the bubble
    input.value = ""
  }

  sendOnEnter(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.element.requestSubmit()
    }
  }

  reset(event) {
    const thinking = document.getElementById("ai_chat_thinking")
    if (thinking) thinking.remove()

    const pending = document.getElementById("ai_chat_user_pending")
    if (pending) pending.remove()

    const input = document.getElementById("ai_chat_input")
    if (input) {
      input.value = ""
      input.focus()
    }

    const messages = document.getElementById("ai_chat_messages")
    if (messages) messages.scrollTop = messages.scrollHeight
  }

  normalizeUserMessage(text) {
    return text
      .replace(/^[ \t]+/, "")
      .replace(/\s+$/, "")
  }
}
