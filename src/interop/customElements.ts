export function init() {
  customElements.define(
    "modal-dialog-controller",
    class extends HTMLElement {
      static get observedAttributes() {
        return ["open"];
      }
      constructor() {
        super();
      }

      connectedCallback() {
        this.render();
      }

      attributeChangedCallback() {
        this.render();
      }

      render() {
        const dialog = this.querySelector("dialog");
        if (!dialog) return;

        if (
          !dialog.getAttribute("aria-labelledby") &&
          !dialog.getAttribute("ari-label")
        ) {
          const headings = dialog.querySelectorAll("h2");
          if (headings.length === 0) {
            console.error("modal-dialog-controller: no headings found");
          }
          const labelledBy: Array<string> = [];
          for (const heading of headings) {
            const id = heading.id ?? "h2-" + slugify(heading.textContent!);
            heading.id = id;
            labelledBy.push(id);
          }
          dialog.setAttribute("aria-labelledby", labelledBy.join(" "));
        }

        const open = this.getAttribute("open") === "true";
        if (open) {
          dialog.showModal();
        } else {
          dialog.close();
        }
      }
    }
  );

  customElements.define(
    "intersection-sentinel",
    class extends HTMLElement {
      observer: IntersectionObserver;
      constructor() {
        super();
        this.observer = new IntersectionObserver(
          (entries) => {
            entries.forEach((entry) => {
              if (entry.isIntersecting && !this.disabled) {
                this.dispatchEvent(new CustomEvent("intersect"));
              }
            });
          },
          {
            rootMargin: "400px",
          }
        );
      }

      set disabled(value: boolean) {
        if (value) {
          this.observer.unobserve(this);
        } else {
          this.observer.observe(this);
        }
      }

      connectedCallback() {
        if (!this.disabled) {
          this.observer.observe(this);
        }
      }

      disconnectedCallback() {
        this.observer.disconnect();
      }
    }
  );

  function slugify(str: string) {
    return str
      .toLowerCase()
      .replace(/[^a-z0-9 ]/g, "")
      .replace(/ /g, "-");
  }
}
