import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "newForm", "newInput", "renameForm", "renameDisplay", "renameInput", "renameActions"]

  connect() {
    this.boundClose = this.closeOnOutsideClick.bind(this)
  }

  toggle() {
    this.menuTarget.classList.contains("hidden") ? this.open() : this.close()
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    document.addEventListener("click", this.boundClose)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.hideNewForm()
    this.resetRenameState()
    document.removeEventListener("click", this.boundClose)
  }

  toggleNewForm(event) {
    event.preventDefault()
    if (this.newFormTarget.classList.contains("hidden")) {
      this.resetRenameState()
      this.newFormTarget.classList.remove("hidden")
      this.focusInputAtEnd(this.newInputTarget)
    } else {
      this.hideNewForm()
    }
  }

  cancelNewForm(event) {
    event.preventDefault()
    this.hideNewForm()
  }

  showRename(event) {
    event.preventDefault()
    const id = String(event.params.id)
    this.hideNewForm()
    this.resetRenameState()

    const form = this.findByDraftId(this.renameFormTargets, id)
    if (!form) return

    form.classList.remove("hidden")
    const display = this.findByDraftId(this.renameDisplayTargets, id)
    if (display) display.classList.add("hidden")
    const actions = this.findByDraftId(this.renameActionsTargets, id)
    if (actions) actions.classList.add("hidden")

    const input = this.findByDraftId(this.renameInputTargets, id) || form.querySelector("input[type='text']")
    if (input) this.focusInputAtEnd(input)
  }

  cancelRename(event) {
    event.preventDefault()
    const id = String(event.params.id)
    const form = this.findByDraftId(this.renameFormTargets, id)
    if (form) form.classList.add("hidden")
    const display = this.findByDraftId(this.renameDisplayTargets, id)
    if (display) display.classList.remove("hidden")
    const actions = this.findByDraftId(this.renameActionsTargets, id)
    if (actions) actions.classList.remove("hidden")
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
  }

  hideNewForm() {
    if (!this.hasNewFormTarget) return

    this.newFormTarget.classList.add("hidden")
    if (this.hasNewInputTarget) this.newInputTarget.value = ""
  }

  resetRenameState() {
    this.renameFormTargets.forEach((form) => form.classList.add("hidden"))
    this.renameDisplayTargets.forEach((display) => display.classList.remove("hidden"))
    this.renameActionsTargets.forEach((actions) => actions.classList.remove("hidden"))
  }

  findByDraftId(targets, id) {
    return targets.find((target) => target.dataset.draftId === id)
  }

  focusInputAtEnd(input) {
    input.focus()
    const len = input.value.length
    input.setSelectionRange(len, len)
  }
}
