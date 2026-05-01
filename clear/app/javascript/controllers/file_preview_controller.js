import { Controller } from "@hotwired/stimulus"

// Swaps a file picker label between a default prompt and the selected
// filename, and toggles a paired submit button.
export default class extends Controller {
  static targets = ["input", "name", "submit"]
  static values = { defaultLabel: { type: String, default: "Select file from your computer" } }

  connect() {
    this.update()
  }

  // Runs on connect and on every file input change.
  update() {
    const file = this.inputTarget.files?.[0]
    if (!file) {
      // No file selected: show default label and keep submit disabled.
      this.nameTarget.textContent = this.defaultLabelValue
      if (this.hasSubmitTarget) this.submitTarget.disabled = true
      return
    }

    // File selected: show its name and enable submit.
    this.nameTarget.textContent = file.name
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
  }
}
