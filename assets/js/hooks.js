const Hooks = {
  HideFlash: {
    mounted() {
      setTimeout(() => {
        if (this.el) {
          console.log("Auto-hiding flash message");
          // Add fade out animation
          this.el.style.transition = 'opacity 0.5s ease-out';
          this.el.style.opacity = '0';
          
          // Remove the element after animation completes
          setTimeout(() => {
            if (this.el && this.el.parentNode) {
              this.el.parentNode.removeChild(this.el);
            }
          }, 500);
        }
      }, 3000);
    }
  }
};

export default Hooks;
