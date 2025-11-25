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

      this.handleEvent("submit_dropout_import", ({ url, sheet_url, type, start_row }) => {
        // Create a form and submit it to the authenticated endpoint
        // This will trigger the browser's basic auth prompt
        const form = document.createElement('form');
        form.method = 'POST';
        form.action = url;
        form.style.display = 'none';

        // Add CSRF token
        const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
        const csrfInput = document.createElement('input');
        csrfInput.type = 'hidden';
        csrfInput.name = '_csrf_token';
        csrfInput.value = csrfToken;
        form.appendChild(csrfInput);

        // Add form fields
        const sheetUrlInput = document.createElement('input');
        sheetUrlInput.type = 'hidden';
        sheetUrlInput.name = 'import[sheet_url]';
        sheetUrlInput.value = sheet_url;
        form.appendChild(sheetUrlInput);

        const typeInput = document.createElement('input');
        typeInput.type = 'hidden';
        typeInput.name = 'import[type]';
        typeInput.value = type;
        form.appendChild(typeInput);

        const startRowInput = document.createElement('input');
        startRowInput.type = 'hidden';
        startRowInput.name = 'import[start_row]';
        startRowInput.value = start_row;
        form.appendChild(startRowInput);

        document.body.appendChild(form);
        form.submit();
      });
    }
  }
};

export default Hooks;
