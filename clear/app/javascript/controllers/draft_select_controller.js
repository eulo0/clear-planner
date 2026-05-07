import { Controller } from "@hotwired/stimulus"

const SELECTED_STYLE = {
  borderColor: "color-mix(in srgb, var(--studs-accent) 65%, var(--studs-border))",
  backgroundColor: "color-mix(in srgb, var(--studs-accent) 16%, var(--studs-panel-bg-2))",
  color: "#ecfeff",
  boxShadow: "0 0 0 1px color-mix(in srgb, var(--studs-accent) 22%, transparent) inset",
}

const UNSELECTED_STYLE = {
  borderColor: "var(--studs-border)",
  backgroundColor: "color-mix(in srgb, var(--studs-panel-bg) 55%, #09090b)",
  color: "#f4f4f5",
  boxShadow: "",
}

export default class extends Controller {
  static targets = ["option"]

  pick(event) {
    const clicked = event.currentTarget
    this.optionTargets.forEach(btn => Object.assign(btn.style, UNSELECTED_STYLE))
    Object.assign(clicked.style, SELECTED_STYLE)
    this.dismiss()
    this.hollowCancel()
  }

  dismiss() {
    this.element.classList.add("pointer-events-none")
  }

  hollowCancel() {
    const card = this.element.querySelector("[data-draft-select-card]") || this.element
    const btn = card.querySelector(".studs-nav-btn")
    if (!btn) return
    btn.style.backgroundColor = "transparent"
    btn.style.boxShadow = "none"
    btn.style.opacity = "0.5"
  }


  cancel() {
    this.element.classList.add("hidden")
  }

  showNewForm(event) {
    const btn = event.currentTarget
    const form = btn.nextElementSibling
    btn.style.display = "none"
    form.style.display = ""
    form.querySelector('input[type="text"]')?.focus()
  }

  hideNewForm(event) {
    const wrapper = event.currentTarget.closest("form").parentElement
    wrapper.style.display = "none"
    wrapper.previousElementSibling.style.display = ""
  }

  onNewDraftSubmit(event) {
    if (!event.detail.success) return

    const form = event.target
    const name = form.querySelector('input[type="text"]')?.value?.trim()
    if (!name) return

    const list = this.element.querySelector("[data-draft-options]")
    if (list) {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "w-full inline-flex items-center justify-between rounded-2xl px-3 py-1.5 text-left border"
      Object.assign(btn.style, SELECTED_STYLE)
      btn.innerHTML = `<span class="truncate">${name}</span>`
      list.appendChild(btn)
    }

    // Hide the entire new draft section (button + form wrapper)
    const newDraftSection = form.closest("[data-new-draft-section]")
    if (newDraftSection) newDraftSection.style.display = "none"

    this.hollowCancel()
    this.dismiss()
  }
}
