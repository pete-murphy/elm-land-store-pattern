import "@github/relative-time-element";

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
          // Clear all inputs
          const inputs = dialog.querySelectorAll("input, textarea, select");
          for (const input of inputs) {
            if (input instanceof HTMLInputElement) {
              input.value = "";
            } else if (input instanceof HTMLTextAreaElement) {
              input.value = "";
            } else if (input instanceof HTMLSelectElement) {
              input.value = "";
            }
          }

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

  customElements.define(
    "locale-datetime",
    class extends HTMLElement {
      dateTimeFormat: null | Intl.DateTimeFormat = null;
      static get observedAttributes() {
        return ["millis", "date-style", "time-style"];
      }
      constructor() {
        super();
      }

      connectedCallback() {
        this.render();
      }

      attributeChangedCallback(
        name: string,
        oldValue: string,
        newValue: string
      ) {
        this.render();
      }

      render() {
        const millis = +this.getAttribute("millis")!;
        if (isNaN(millis)) {
          console.error(
            "locale-datetime: invalid millis",
            this.getAttribute("millis")
          );
          return;
        }
        const date = new Date(millis);
        const dateStyle = (this.getAttribute("date-style") ?? undefined) as
          | Intl.DateTimeFormatOptions["dateStyle"]
          | undefined;
        const timeStyle = (this.getAttribute("time-style") ?? undefined) as
          | Intl.DateTimeFormatOptions["timeStyle"]
          | undefined;

        this.innerText = new Intl.DateTimeFormat(undefined, {
          dateStyle: dateStyle,
          timeStyle: timeStyle,
        }).format(date);
      }
    }
  );
}

function slugify(str: string) {
  return str
    .toLowerCase()
    .replace(/[^a-z0-9 ]/g, "")
    .replace(/ /g, "-");
}
