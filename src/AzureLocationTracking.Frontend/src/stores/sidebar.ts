import { computed, ref } from "vue";
import { defineStore } from "pinia";

export const useSidebarStore = defineStore("sidebar", () => {
  const selectedVehicleId = ref<string | null>(null);
  const isOpen = computed(() => selectedVehicleId.value !== null);

  function openSidebar(vehicleId: string) {
    selectedVehicleId.value = vehicleId;
  }

  function closeSidebar() {
    selectedVehicleId.value = null;
  }

  return {
    isOpen,
    selectedVehicleId,
    closeSidebar,
    openSidebar,
  };
});
