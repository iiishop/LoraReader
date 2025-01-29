<script setup>
const props = defineProps({
    currentModule: {
        type: String,
        required: true
    }
});

const emit = defineEmits(['module-change']);

const menuItems = [
    { id: 'lora', icon: '📚', label: 'Lora 预览' },
    { id: 'settings', icon: '⚙️', label: '设置' }
];
</script>

<template>
    <div class="navigation-menu">
        <div class="menu-items">
            <button
                v-for="item in menuItems"
                :key="item.id"
                class="menu-item"
                :class="{ active: currentModule === item.id }"
                @click="emit('module-change', item.id)"
            >
                <span class="icon">{{ item.icon }}</span>
                <span class="label">{{ item.label }}</span>
            </button>
        </div>
    </div>
</template>

<style scoped>
.navigation-menu {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    background: white;
    padding: 0.5rem;
    box-shadow: 0 -2px 10px rgba(0,0,0,0.1);
    z-index: 1000;
}

.menu-items {
    display: flex;
    justify-content: center;
    gap: 2rem;
    max-width: 600px;
    margin: 0 auto;
}

.menu-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 0.5rem 1rem;
    border: none;
    background: none;
    cursor: pointer;
    transition: all 0.3s ease;
    border-radius: 8px;
}

.menu-item.active {
    background: #f0f0f0;
    color: #4a90e2;
}

.icon {
    font-size: 1.5rem;
    margin-bottom: 0.3rem;
}

.label {
    font-size: 0.8rem;
}

.menu-item:hover {
    background: #f8f8f8;
}
</style>
