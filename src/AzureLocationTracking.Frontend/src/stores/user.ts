import { computed, ref } from "vue";
import { defineStore } from "pinia";
import type { AccountInfo } from "@azure/msal-browser";

export const useUserStore = defineStore("user", () => {
  const account = ref<AccountInfo | null>(null);
  const isAuthenticated = computed(() => account.value !== null);

  function setAccount(acc: AccountInfo | null) {
    account.value = acc;
  }

  return {
    account,
    isAuthenticated,
    setAccount,
  };
});
