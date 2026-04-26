import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    clear() {
        window.Turbo?.cache?.clear?.()
    }
}