import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import Hooks from "./hooks";

let csrfToken = document
    .querySelector("meta[name='csrf-token']")
    .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
    params: { _csrf_token: csrfToken },
    hooks: Hooks
});

// Connect if there are any LiveViews on the page
liveSocket.connect();

window.liveSocket = liveSocket;
