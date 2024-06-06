<script setup lang="ts">
import { getAccessToken } from '@/services/login';
import { useSidebarStore } from '@/stores/sidebar';
import { useUserStore } from '@/stores/user';
import { ref } from 'vue';
import VehicleGeofenceEvents from './VehicleGeofenceEvents.vue';
import { useVehicleStore } from '@/stores/vehicle';

const sidebarStore = useSidebarStore();
const userStore = useUserStore();
const vehicleStore = useVehicleStore();

const speedValue = ref('');
const updateIntervalValue = ref('');

function onParametersSendClick() {
    getAccessToken().then(accessToken => {
        const speed = Number(speedValue.value);
        const updateInterval = Number(updateIntervalValue.value);
        if (isNaN(speed) || isNaN(updateInterval) || speed <= 0 || updateInterval < 100) {
            return;
        }

        const parameters = {
            SpeedKilometersPerHour: speed,
            EventIntervalMillis: updateInterval
        };
        return fetch(`/api/vehicles/${sidebarStore.selectedVehicleId}/parameters`, {
            method: 'PUT',
            headers: {
                Authorization: `Bearer ${accessToken}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(parameters)
        });
    }).then((res) => {
        if (res === undefined || res.status !== 204) {
            throw new Error('Failed to update parameters');
        }

        console.info('Parameters updated');
        speedValue.value = '';
        updateIntervalValue.value = '';
    }).catch(err => {
        console.error(err);
    });
}
</script>

<template>
    <div v-if="sidebarStore.isOpen" class="container">
        <button type="button" class="btn-close" @click="sidebarStore.closeSidebar">Close</button>
        <p>
            <b>Vehicle ID:</b> <span id="vehicleIdDisplay">{{ sidebarStore.selectedVehicleId }}</span>
        </p>
        <p>
            <b>Speed:</b> <span id="speedDisplay">{{ vehicleStore.vehicles[sidebarStore.selectedVehicleId ??
                '']?.speed?.toFixed(0) ?? '-' }}</span> km/h
        </p>
        <p>
            <b>Heading:</b> <span id="headingDisplay">{{ vehicleStore.vehicles[sidebarStore.selectedVehicleId ??
                '']?.heading?.toFixed(2) ?? '-' }}</span>
            degrees
        </p>

        <div id="parametersForm" v-if="userStore.isAuthenticated">
            <h2>Parameters</h2>
            <label for="speedInput">Speed (km/h)</label><br />
            <input type="text" v-model="speedValue" /><br />

            <label for="updateIntervalInput">Location update interval (ms)</label><br />
            <input type="text" v-model="updateIntervalValue" /><br />

            <button type="button" @click="onParametersSendClick">Send</button>
        </div>

        <VehicleGeofenceEvents :vehicle-id="sidebarStore.selectedVehicleId" />
    </div>
</template>

<style scoped>
.container {
    position: absolute;
    top: 0;
    right: 0;
    bottom: 0;
    width: 440px;
    max-width: 100%;
    background-color: white;
    padding: 16px;
    z-index: 1;
    box-sizing: border-box;
}

.container .btn-close {
    float: right;
}
</style>