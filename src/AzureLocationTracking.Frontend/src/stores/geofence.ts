import { ref } from "vue";
import { defineStore } from "pinia";
import type atlas from "azure-maps-control";
import { getGeofences } from "@/api/geofences";

export const useGeofenceStore = defineStore("geofence", () => {
  const geofences = ref<atlas.data.FeatureCollection>({
    features: [],
    type: "FeatureCollection",
  });

  function loadGeofences() {
    getGeofences().then((response) => {
      geofences.value = response;
    });
  }

  function getGeofenceName(id: string | number) {
    return geofences.value.features.find((f) => f.id === id)?.properties?.name;
  }

  return {
    geofences,
    loadGeofences,
    getGeofenceName,
  };
});
