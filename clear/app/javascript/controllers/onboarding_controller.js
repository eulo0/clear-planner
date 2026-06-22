import { Controller } from "@hotwired/stimulus"

// Single-page onboarding step machine (ported from Clear Onboarding.html),
// wired to the real backend over fetch: welcome -> upload -> parsing (live
// scan while the real parse runs) -> reveal (editable cards) -> done.
export default class extends Controller {
  static targets = [
    "step", "drop", "input", "filelist", "submit", "submitNoun",
    "reveal", "scanStatus", "scanBar", "scanTitle", "doneCourses", "doneSessions"
  ]
  static values = {
    max: { type: Number, default: 8 },
    filesUrl: String, statusUrl: String, reviewUrl: String, confirmUrl: String,
    skipUrl: String, dashboardUrl: String
  }

  connect() {
    this.cur = 0
    this.busy = false
    this.dt = new DataTransfer()
    this.reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.show(0)
    setTimeout(() => this.setHeight(), 60)
    this._resize = () => this.setHeight()
    window.addEventListener("resize", this._resize)
  }

  disconnect() {
    window.removeEventListener("resize", this._resize)
    this.clearParse()
  }

  // ── step machine ──────────────────────────────────────────
  show(i) {
    this.cur = i
    this.stepTargets.forEach((s, idx) => {
      s.classList.toggle("active", idx === i)
      s.classList.remove("leaving")
    })
    this.setHeight()
    requestAnimationFrame(() => this.focusStep())
  }

  go(i) {
    if (this.busy || i === this.cur) return
    this.busy = true
    const old = this.stepTargets[this.cur]
    old.classList.add("leaving")
    setTimeout(() => {
      old.classList.remove("active", "leaving")
      this.show(i)
      this.busy = false
    }, this.reduce ? 10 : 230)
  }

  setHeight() {
    const active = this.stepTargets[this.cur]
    if (active) this.element.style.height = `${active.scrollHeight}px`
  }

  focusStep() {
    const el = this.stepTargets[this.cur].querySelector("[data-autofocus]")
    if (el) el.focus({ preventScroll: true })
  }

  toUpload() { this.go(1) }

  // ── upload (native drag-drop, multi-file) ─────────────────
  browse() { this.inputTarget.click() }
  keyBrowse(e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); this.browse() } }
  dragover(e) { e.preventDefault(); this.dropTarget.classList.add("dragover") }
  dragleave(e) { e.preventDefault(); this.dropTarget.classList.remove("dragover") }
  drop(e) { e.preventDefault(); this.dropTarget.classList.remove("dragover"); this.addFiles(e.dataTransfer.files) }
  filesChosen() { this.addFiles(this.inputTarget.files) }

  addFiles(fileList) {
    const ok = /\.(pdf|docx?)$/i
    Array.from(fileList).forEach((file) => {
      if (this.dt.items.length >= this.maxValue) return
      if (!ok.test(file.name)) return
      if (Array.from(this.dt.files).some((f) => f.name === file.name && f.size === file.size)) return
      this.dt.items.add(file)
    })
    this.inputTarget.files = this.dt.files
    this.renderFiles()
  }

  stopPropagation(e) { e.stopPropagation() }

  removeFile(e) {
    e.stopPropagation()
    const idx = Number(e.currentTarget.dataset.index)
    const next = new DataTransfer()
    Array.from(this.dt.files).forEach((f, i) => { if (i !== idx) next.items.add(f) })
    this.dt = next
    this.inputTarget.files = this.dt.files
    this.renderFiles()
  }

  renderFiles() {
    const files = Array.from(this.dt.files)
    this.filelistTarget.innerHTML = files.map((f, i) => `
      <div class="filepill">
        <span class="fic"></span>
        <div style="text-align:left">
          <div class="fname">${this.escape(f.name)}</div>
          <div class="fmeta">${this.size(f.size)} · ready to read</div>
        </div>
        <button type="button" class="fx" data-action="onboarding#removeFile" data-index="${i}" aria-label="Remove">&times;</button>
      </div>`).join("")
    this.submitTarget.style.display = files.length ? "" : "none"
    if (this.hasSubmitNounTarget) this.submitNounTarget.textContent = files.length > 1 ? "syllabi" : "syllabus"
    this.setHeight()
  }

  // ── submit files -> parse ─────────────────────────────────
  async submitFiles(e) {
    e.preventDefault()
    if (this.dt.files.length === 0) return
    const body = new FormData(e.target.closest("form"))
    this.submitTarget.disabled = true

    let ok = false
    try { ok = (await this.post(this.filesUrlValue, body)).ok } catch (_) { ok = false }

    if (!ok) { this.submitTarget.disabled = false; return }

    this.go(2)
    this.runParse()
  }

  // ── parsing: live scan + poll real status ─────────────────
  runParse() {
    this.clearParse()
    this.parseStart = Date.now()
    this.parseError = false
    const messages = [
      "Scanning document structure…",
      "Reading course details…",
      "Picking up meeting days and times…",
      "Identifying key dates…",
      "Assembling your course…"
    ]
    let mi = 0, pct = 8
    if (this.hasScanBarTarget) this.scanBarTarget.style.width = "8%"
    this.msgTimer = setInterval(() => {
      mi = Math.min(mi + 1, messages.length - 1)
      if (this.hasScanStatusTarget) this.scanStatusTarget.textContent = messages[mi]
      pct = Math.min(pct + 16, 90)
      if (this.hasScanBarTarget) this.scanBarTarget.style.width = `${pct}%`
    }, this.reduce ? 250 : 620)

    this.pollTimer = setInterval(() => this.pollStatus(), 700)
    this.pollStatus()
  }

  async pollStatus() {
    let settled = false
    try {
      const res = await fetch(this.statusUrlValue, { headers: { Accept: "application/json" } })
      if (res.ok) settled = (await res.json()).settled
    } catch (_) { /* keep polling */ }

    const minElapsed = Date.now() - this.parseStart >= (this.reduce ? 600 : 2200)
    if ((settled || this.parseError) && minElapsed) this.finishParse()
  }

  async finishParse() {
    this.clearParse()
    if (this.hasScanBarTarget) this.scanBarTarget.style.width = "100%"
    try {
      const res = await fetch(`${this.reviewUrlValue}?fragment=1`, { headers: { "X-Onboarding-Fetch": "1" } })
      if (res.redirected || !res.ok || res.status === 204) { window.location = this.dashboardUrlValue; return }
      this.revealTarget.innerHTML = await res.text()
    } catch (_) {
      window.location = this.dashboardUrlValue; return
    }
    setTimeout(() => this.go(3), this.reduce ? 0 : 250)
  }

  clearParse() {
    clearInterval(this.msgTimer)
    clearInterval(this.pollTimer)
  }

  // ── reveal -> confirm ─────────────────────────────────────
  async addToCalendar(e) {
    e.preventDefault()
    const form = e.target.closest("form")
    const body = new FormData(form)
    const res = await this.post(this.confirmUrlValue, body)

    if (res.ok && res.headers.get("content-type")?.includes("application/json")) {
      const data = await res.json()
      if (this.hasDoneCoursesTarget) this.doneCoursesTarget.textContent = data.courses_label
      if (this.hasDoneSessionsTarget) this.doneSessionsTarget.textContent = data.sessions_label
      this.go(4)
    } else {
      // validation errors — re-render the cards with messages
      this.revealTarget.innerHTML = await res.text()
      this.setHeight()
    }
  }

  // ── skip / finish ─────────────────────────────────────────
  async skip(e) {
    e.preventDefault()
    try { await this.post(this.skipUrlValue, new FormData()) } catch (_) { /* navigate anyway */ }
    this.finish()
  }

  finish(e) {
    e?.preventDefault()
    this.clearParse()
    // dismissed: panel exits and real calendar iframe simultaneously un-blurs
    document.body.classList.add("dismissed")
    setTimeout(() => {
      if (typeof Turbo !== "undefined") {
        Turbo.visit(this.dashboardUrlValue, { action: "replace" })
      } else {
        window.location = this.dashboardUrlValue
      }
    }, this.reduce ? 100 : 500)
  }

  // ── helpers ───────────────────────────────────────────────
  post(url, body) {
    return fetch(url, {
      method: "POST",
      body,
      headers: { "X-CSRF-Token": this.csrf(), "X-Onboarding-Fetch": "1", Accept: "application/json" }
    })
  }

  csrf() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  size(b) {
    if (b < 1024) return `${b} B`
    if (b < 1024 * 1024) return `${Math.round(b / 1024)} KB`
    return `${(b / 1024 / 1024).toFixed(1)} MB`
  }

  escape(s) {
    const d = document.createElement("div"); d.textContent = s; return d.innerHTML
  }
}
