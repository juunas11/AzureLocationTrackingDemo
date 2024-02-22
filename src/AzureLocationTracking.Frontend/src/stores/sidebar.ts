import { computed, ref } from "vue";
import { defineStore } from "pinia";

export const useSidebarStore = defineStore("sidebar", () => {
  const selectedTrackerId = ref<string | null>(null);
  const isOpen = computed(() => selectedTrackerId.value !== null);

  function openSidebar(trackerId: string) {
    selectedTrackerId.value = trackerId;
  }

  function closeSidebar() {
    selectedTrackerId.value = null;
  }

  return {
    isOpen,
    selectedTrackerId,
    closeSidebar,
    openSidebar,
  };
});
