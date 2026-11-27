import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"]

  toggle() {
    const visible = this.inputTarget.type === "password"
    this.inputTarget.type = visible ? "text" : "password"
    this.buttonTarget.textContent = visible ? "Hide password" : "Show password"
    this.buttonTarget.setAttribute("aria-pressed", String(visible))
  }
}
