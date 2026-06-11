import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["micButton", "micIcon", "stopIcon"]
  static values  = { inputId: String }

  connect() {
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition
    if (!SR) {
      this.micButtonTarget.title = "Voice input is not supported in this browser"
      this.micButtonTarget.style.opacity = "0.4"
      this.micButtonTarget.style.cursor  = "not-allowed"
      return
    }

    this.recognition = new SR()
    this.recognition.continuous     = true
    this.recognition.interimResults = true
    this.recognition.lang           = navigator.language || "en-US"

    this.recognition.onresult = (event) => this.#onResult(event)
    this.recognition.onend    = ()      => this.#onEnd()
    this.recognition.onerror  = (event) => this.#onError(event)

    this.finalTranscript = ""
    this.recording = false

    this._onSubmit = () => {
      this.finalTranscript = ""
      this.recognition.onresult = null
      if (this.recording) this.#stop()
    }
    this.element.addEventListener("turbo:submit-start", this._onSubmit)

    const input = document.getElementById(this.inputIdValue)
    if (input) {
      this._onKeydown = (event) => {
        if (event.key === "Enter" && !event.shiftKey && this.recording) {
          event.stopImmediatePropagation()
          event.preventDefault()
          this.#stop()
        }
      }
      this._onManualInput = () => {
        if (this.recording) this.finalTranscript = input.value
      }
      input.addEventListener("keydown", this._onKeydown)
      input.addEventListener("input", this._onManualInput)
    }
  }

  disconnect() {
    this.recognition?.stop()
    this.element.removeEventListener("turbo:submit-start", this._onSubmit)
    const input = document.getElementById(this.inputIdValue)
    if (input) {
      if (this._onKeydown) input.removeEventListener("keydown", this._onKeydown)
      if (this._onManualInput) input.removeEventListener("input", this._onManualInput)
    }
  }

  toggle() {
    if (!this.recognition) return
    this.recording ? this.#stop() : this.#start()
  }

  #start() {
    const input = document.getElementById(this.inputIdValue)
    const base = input?.value.trimEnd() ?? ""
    this.finalTranscript = base ? base + " " : ""
    this.recording = true
    this.recognition.onresult = (event) => this.#onResult(event)
    input?.focus()

    this.micButtonTarget.style.backgroundColor = "#dc2626"
    this.micButtonTarget.style.boxShadow = "0 0 12px rgba(220,38,38,0.5)"
    this.micButtonTarget.style.border = "none"
    this.micIconTarget.classList.add("hidden")
    this.stopIconTarget.classList.remove("hidden")

    try {
      this.recognition.start()
    } catch {
      this.#onEnd()
    }
  }

  #stop() {
    this.recording = false
    this.recognition.stop()
  }

  #onResult(event) {
    let interim = ""

    for (let i = event.resultIndex; i < event.results.length; i++) {
      const transcript = event.results[i][0].transcript
      if (event.results[i].isFinal) {
        this.finalTranscript += transcript
      } else {
        interim += transcript
      }
    }

    const input = document.getElementById(this.inputIdValue)
    if (input) input.value = (this.finalTranscript + interim).trimStart()
  }

  #onEnd() {
    this.recording = false
    this.micButtonTarget.style.backgroundColor = ""
    this.micButtonTarget.style.boxShadow = ""
    this.micButtonTarget.style.border = ""
    this.micIconTarget.classList.remove("hidden")
    this.stopIconTarget.classList.add("hidden")
  }

  #onError(event) {
    if (event.error === "not-allowed") {
      this.micButtonTarget.title = "Microphone access was denied"
    }
    this.#onEnd()
  }
}
