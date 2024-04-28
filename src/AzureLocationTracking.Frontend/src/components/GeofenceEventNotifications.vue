<script setup lang="ts">
import { emitter, type Events } from '@/services/eventBus';
import { useGeofenceStore } from '@/stores/geofence';
import { onMounted, onUnmounted, ref } from 'vue';

interface GeofenceEvent {
    vehicleId: string;
    geofenceId: number;
    geofenceName: string;
    eventType: 'entered' | 'exited';
}

const geofenceStore = useGeofenceStore();
const geofenceEvents = ref<GeofenceEvent[]>([]);

function addGeofenceEvent(vehicleId: string, geofenceId: number, eventType: 'entered' | 'exited') {
    const name = geofenceStore.getGeofenceName(geofenceId);
    geofenceEvents.value.push({
        vehicleId,
        geofenceId,
        geofenceName: name,
        eventType
    });
}

function removeOldestGeofenceEvent() {
    geofenceEvents.value.shift();
}

function onGeofenceEntered({ vehicleId, geofenceId }: Events['geofenceEntered']) {
    addGeofenceEvent(vehicleId, geofenceId, 'entered');
    setTimeout(removeOldestGeofenceEvent, 5000);
}

function onGeofenceExited({ vehicleId, geofenceId }: Events['geofenceExited']) {
    addGeofenceEvent(vehicleId, geofenceId, 'exited');
    setTimeout(removeOldestGeofenceEvent, 5000);
}

onMounted(() => {
    emitter.on('geofenceEntered', onGeofenceEntered);
    emitter.on('geofenceExited', onGeofenceExited);
});
onUnmounted(() => {
    emitter.off('geofenceEntered', onGeofenceEntered);
    emitter.off('geofenceExited', onGeofenceExited);
});
</script>

<template>
    <div class="eventsContainer">
        <p v-for="geofenceEvent in geofenceEvents">{{ `Vehicle ${geofenceEvent.vehicleId} ${geofenceEvent.eventType}
                    geofence ${geofenceEvent.geofenceName ?? "Unknown"} (${geofenceEvent.geofenceId})` }}</p>
    </div>
</template>

<style scoped>
.eventsContainer {
    position: absolute;
    top: 16px;
    left: 64px;
    background-color: transparent;
}

.eventsContainer>p {
    background-color: white;
    border-radius: 4px;
    padding: 8px;
    margin: 0;
    margin-bottom: 8px;
}
</style>