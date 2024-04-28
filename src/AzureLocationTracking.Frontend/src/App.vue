<script setup lang="ts">
import Map from './components/Map.vue'
import LoginDisplay from './components/LoginDisplay.vue'
import Sidebar from './components/Sidebar.vue'
import GeofenceEventNotifications from './components/GeofenceEventNotifications.vue'
import { connection, startConnection } from '@/services/signalr';
import {
  type AccountInfo,
  type AuthenticationResult,
} from "@azure/msal-browser";
import { getAllAccounts, initialize, setActiveAccount } from '@/services/login';
import { emitter } from '@/services/eventBus';
import { useUserStore } from './stores/user';
import { onMounted, onUnmounted } from 'vue';
import { useVehicleStore } from './stores/vehicle';
import { useGeofenceStore } from './stores/geofence';

startConnection();

const userStore = useUserStore();
const vehicleStore = useVehicleStore();
const geofenceStore = useGeofenceStore();

function handleLoginResponse(response: AuthenticationResult | null) {
  if (response !== null && response.account !== null) {
    // User signed in
    setUserSignedIn(response.account);
  } else {
    // User did not sign in, might be signed in already though
    const currentAccounts = getAllAccounts();
    if (currentAccounts && currentAccounts.length === 1) {
      setUserSignedIn(currentAccounts[0]);
    }
  }
}

function setUserSignedIn(account: AccountInfo) {
  userStore.setAccount(account);
  setActiveAccount(account);
}

initialize(handleLoginResponse);

function onLocationUpdated(vehicleId: string, latitude: number, longitude: number, timestamp: number) {
  emitter.emit('locationUpdated', { vehicleId, latitude, longitude, timestamp });
}

function onGeofenceEntered(vehicleId: string, geofenceId: number) {
  emitter.emit('geofenceEntered', { vehicleId, geofenceId });
};

function onGeofenceExited(vehicleId: string, geofenceId: number) {
  emitter.emit('geofenceExited', { vehicleId, geofenceId });
};

onMounted(() => {
  connection.on("locationUpdated", onLocationUpdated);
  connection.on("geofenceEntered", onGeofenceEntered);
  connection.on("geofenceExited", onGeofenceExited);
  vehicleStore.subscribeLocationEvents();
  geofenceStore.loadGeofences();
});
onUnmounted(() => {
  connection.off("locationUpdated", onLocationUpdated);
  connection.off("geofenceEntered", onGeofenceEntered);
  connection.off("geofenceExited", onGeofenceExited);
  vehicleStore.unsubscribeLocationEvents();
});
</script>

<template>
  <Map />
  <LoginDisplay />
  <Sidebar />
  <GeofenceEventNotifications />
</template>
