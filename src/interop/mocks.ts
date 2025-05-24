import { setupWorker } from "msw/browser";
import { handlers } from "../../mocks/mocks";

const worker = setupWorker(...handlers);

export const init = () => worker.start();
