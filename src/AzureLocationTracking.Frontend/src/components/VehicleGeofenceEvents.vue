<script setup lang="ts">
import { getGeofenceEvents } from '@/api/geofenceEvents';
import { emitter, type Events } from '@/services/eventBus';
import { onMounted, onUnmounted, ref, watch } from 'vue';

interface GeofenceEvent {
    geofenceId: number;
    entryTimestamp: string;
    exitTimestamp: string | null;
}

const props = defineProps<{ vehicleId: string | null | undefined }>();
const geofenceEvents = ref<GeofenceEvent[]>([]);

watch(() => props.vehicleId, (id: string | null | undefined) => {
    if (id !== null && id !== undefined) {
        geofenceEvents.value = [];
        updateGeofenceEvents(id);
    }
}, {
    immediate: true
});

function updateGeofenceEvents(vehicleId: string) {
    getGeofenceEvents(vehicleId)
        .then(events => {
            const dateDisplayOptions: Intl.DateTimeFormatOptions = {
                year: 'numeric',
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
                second: '2-digit',
                hour12: false
            };

            geofenceEvents.value = events.map((e: any) => ({
                geofenceId: e.geofenceId,
                entryTimestamp: new Date(e.entryTimestamp).toLocaleDateString('en-US', dateDisplayOptions),
                exitTimestamp: e.exitTimestamp !== null ? new Date(e.exitTimestamp).toLocaleDateString('en-US', dateDisplayOptions) : '-'
            }));
        })
        .catch(err => console.error(err));
}

function onGeofenceEnteredOrExited(data: Events['geofenceEntered'] | Events['geofenceExited']) {
    if (data.vehicleId === props.vehicleId) {
        updateGeofenceEvents(data.vehicleId);
    }
}

onMounted(() => {
    emitter.on('geofenceEntered', onGeofenceEnteredOrExited);
    emitter.on('geofenceExited', onGeofenceEnteredOrExited);
});
onUnmounted(() => {
    emitter.off('geofenceEntered', onGeofenceEnteredOrExited);
    emitter.off('geofenceExited', onGeofenceEnteredOrExited);
});
</script>

<template>
    <h2>Geofence events</h2>
    <table>
        <thead>
            <tr>
                <th>Geofence</th>
                <th>Entry</th>
                <th>Exit</th>
            </tr>
        </thead>
        <tbody id="geofenceEventsDisplay">
            <tr v-for="geofenceEvent in geofenceEvents">
                <td>Geofence {{ geofenceEvent.geofenceId }}</td>
                <td>{{ geofenceEvent.entryTimestamp }}</td>
                <td>{{ geofenceEvent.exitTimestamp }}</td>
            </tr>
        </tbody>
    </table>
</template>