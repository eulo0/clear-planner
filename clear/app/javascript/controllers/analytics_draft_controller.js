import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    document.addEventListener("turbo:before-stream-render", this.handleStream)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.handleStream)
  }

  handleStream = (event) => {
    // draft_banner is always updated whenever draft state changes
    if (event.target?.getAttribute("target") === "draft_banner") {
      setTimeout(() => this.reloadFrame(), 0)
    }
  }

  reloadFrame() {
    const frame = document.getElementById("analytics_content")
    if (!frame) return
    frame.setAttribute("src", this.urlValue)
    frame.reload()
  }
}
