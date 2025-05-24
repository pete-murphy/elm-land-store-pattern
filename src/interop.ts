import "./main.css";
import * as Mocks from "./interop/mocks";
import * as CustomElements from "./interop/customElements";
import * as Credentials from "./interop/credentials";

// This returns the flags passed into your Elm application
export const flags = async ({ env }: ElmLand.FlagsArgs) => {
  CustomElements.init();
  await Mocks.init();
  const credentials = Credentials.get();
  return {
    credentials,
  };
};

// This function is called after your Elm app starts
export const onReady = ({ app, env }: ElmLand.OnReadyArgs) => {
  console.log("Elm is ready", app);
};

// Type definitions for Elm Land
namespace ElmLand {
  export type FlagsArgs = {
    env: Record<string, string>;
  };
  export type OnReadyArgs = {
    env: Record<string, string>;
    app: { ports?: Record<string, Port> };
  };
  export type Port = {
    send?: (data: unknown) => void;
    subscribe?: (callback: (data: unknown) => unknown) => void;
  };
}
