const Hooks = {
  AutoDismiss: {
    mounted() {
      // Fade in: slight delay for animation
      this.el.style.transition = "opacity 0.3s ease, transform 0.3s ease";
      this.el.style.opacity = "0";
      this.el.style.transform = "translateY(-10px)";

      setTimeout(() => {
        this.el.style.opacity = "1";
        this.el.style.transform = "translateY(0)";
      }, 10);

      // Auto fade out after 3 seconds
      setTimeout(() => {
        this.fadeOut();
      }, 3000);

      // Optional: allow external "close" event
      this.handleEvent("close", () => {
        this.fadeOut();
      });
    },

    fadeOut() {
      this.el.style.transition = "opacity 0.3s ease, transform 0.3s ease";
      this.el.style.opacity = "0";
      this.el.style.transform = "translateY(-10px)";
      setTimeout(() => {
        this.el.remove();
      }, 300); // Give time for transition to complete
    }
  }
};

export default Hooks;
