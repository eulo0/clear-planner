import { Controller } from "@hotwired/stimulus"
import * as FilePond from "filepond"

export default class extends Controller {
  static targets = ["input"]
  static values = {
    allowMultiple: { type: Boolean, default: false },
    maxFiles: { type: Number, default: 1 },
    label: { type: String, default: "" }
  }

  connect() {
    if (!this.hasInputTarget) return
    if (this.pond) return

    this.element.classList.remove("filepond-ready")
    this._beforeCache = () => this.teardown()
    document.addEventListener("turbo:before-cache", this._beforeCache)
    this.pond = FilePond.create(this.inputTarget, {
      allowMultiple: this.allowMultipleValue,
      maxFiles: this.allowMultipleValue ? this.maxFilesValue : 1,
      storeAsFile: true,
      credits: false,
      acceptedFileTypes: [
        "application/pdf",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/msword"
      ],
      labelIdle: this.labelValue || this.defaultLabel(),
      oninit: () => this.element.classList.add("filepond-ready")
    })
  }

  defaultLabel() {
    const browse = (text) =>
      `<span style="color: var(--studs-accent); text-decoration: underline; text-decoration-color: currentColor;">${text}</span>`

    if (this.allowMultipleValue) {
      return `<span style="color: rgb(212 212 216);">Drag & drop, or ${browse("click to browse")}</span>`
    }
    return `<span style="color: rgb(212 212 216);">Drag & Drop your file or ${browse("Browse")}</span>`
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this._beforeCache)
    this._beforeCache = null
    this.teardown()
  }

  teardown() {
    if (!this.pond) return
    this.pond.destroy()
    this.pond = null
    this.element.classList.remove("filepond-ready")
  }
}
