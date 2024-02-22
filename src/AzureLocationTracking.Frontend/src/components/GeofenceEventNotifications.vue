<script setup lang="ts">
import { emitter, type Events } from '@/services/eventBus';
import { onMounted, onUnmounted, ref } from 'vue';

interface GeofenceEvent {
    trackerId: string;
    geofenceId: number;
    eventType: 'entered' | 'exited';
}

const geofenceEvents = ref<GeofenceEvent[]>([]);

function addGeofenceEvent(trackerId: string, geofenceId: number, eventType: 'entered' | 'exited') {
    geofenceEvents.value.push({
        trackerId,
        geofenceId,
        eventType
    });
}

function removeOldestGeofenceEvent() {
    geofenceEvents.value.shift();
}

function onGeofenceEntered({ trackerId, geofenceId }: Events['geofenceEntered']) {
    addGeofenceEvent(trackerId, geofenceId, 'entered');
    setTimeout(removeOldestGeofenceEvent, 5000);
}

function onGeofenceExited({ trackerId, geofenceId }: Events['geofenceExited']) {
    addGeofenceEvent(trackerId, geofenceId, 'exited');
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
        <p v-for="geofenceEvent in geofenceEvents">{{ `Tracker ${geofenceEvent.trackerId} ${geofenceEvent.eventType}
                    geofence ${geofenceEvent.geofenceId}` }}</p>
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