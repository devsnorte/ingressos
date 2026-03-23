import { Html5Qrcode } from "html5-qrcode"

const QRScanner = {
  mounted() {
    this.scanner = null
    this.scanning = false
    this.cooldown = false

    this.startButton = this.el.querySelector("[data-start-scan]")
    this.stopButton = this.el.querySelector("[data-stop-scan]")
    this.readerEl = this.el.querySelector("[data-qr-reader]")

    if (this.startButton) {
      this.startButton.addEventListener("click", () => this.startScan())
    }
    if (this.stopButton) {
      this.stopButton.addEventListener("click", () => this.stopScan())
    }
  },

  async startScan() {
    if (this.scanning) return

    const readerId = this.readerEl.id
    this.scanner = new Html5Qrcode(readerId)

    try {
      await this.scanner.start(
        { facingMode: "environment" },
        { fps: 10, qrbox: { width: 250, height: 250 } },
        (decodedText) => {
          if (this.cooldown) return
          this.cooldown = true
          this.pushEvent("scan", { code: decodedText })
          setTimeout(() => { this.cooldown = false }, 2000)
        },
        (_errorMessage) => {}
      )

      this.scanning = true
      if (this.startButton) this.startButton.classList.add("hidden")
      if (this.stopButton) this.stopButton.classList.remove("hidden")
    } catch (err) {
      console.error("QR Scanner error:", err)
      this.pushEvent("scan_error", { message: "Camera access denied or unavailable" })
    }
  },

  async stopScan() {
    if (!this.scanning || !this.scanner) return

    try {
      await this.scanner.stop()
    } catch (_) {}

    this.scanning = false
    if (this.startButton) this.startButton.classList.remove("hidden")
    if (this.stopButton) this.stopButton.classList.add("hidden")
  },

  async destroyed() {
    await this.stopScan()
  }
}

export default QRScanner
