<script setup lang="ts">
import { login } from '@/services/login';
import { useUserStore } from '@/stores/user';

const userStore = useUserStore();
</script>

<template>
    <div class="loginContainer">
        <button v-if="!userStore.isAuthenticated" type="button" @click="login">Login</button>
        <p v-if="userStore.isAuthenticated">Logged in as: {{ userStore.account?.username }}</p>
    </div>
</template>

<style scoped>
.loginContainer {
    position: absolute;
    bottom: 0;
    left: 50%;
    transform: translateX(-50%);
    background-color: white;
    padding: 16px;
}

.loginContainer>p {
    margin: 0;
}
</style>