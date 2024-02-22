import { HubConnectionBuilder } from "@microsoft/signalr";

export const connection = new HubConnectionBuilder()
  .withUrl("/api/signalr")
  .withAutomaticReconnect()
  .build();

export function startConnection() {
  if (connection.state !== "Disconnected") {
    return;
  }

  connection
    .start()
    .then(function () {
      console.info("SignalR connected");
    })
    .catch(function (reason) {
      console.error(reason);
      setTimeout(startConnection, 5000);
    });
}
