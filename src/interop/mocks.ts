import { setupWorker } from "msw/browser";
import { handlers } from "../../mocks/mocks";

const worker = setupWorker(...handlers("/api", 1000));

export const init = () =>
  worker.start({
    onUnhandledRequest() {
      return undefined;
    },
  });
