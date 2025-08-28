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
  },

  TemplateDownloader: {
    mounted() {
      this.handleEvent("download_file", ({ url }) => {
        // Create a temporary link element and click it to trigger download
        const link = document.createElement('a');
        link.href = url;
        link.download = ''; // This will use the filename from the server
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      });
    }
  }
};

export default Hooks;
