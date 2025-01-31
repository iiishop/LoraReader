<script setup>
import { ref, computed } from 'vue';
import { globalState } from '../utils/globalVar';

const props = defineProps({
    combination: {
        type: Object,
        required: true
    },
    show: Boolean
});

const emit = defineEmits(['close']);

const showCopySuccess = ref(false);

const formattedPrompt = computed(() => {
    const basePrompt = props.combination.positive_prompt;
    const loraPrompts = props.combination.loras
        .map(l => `<${l.name}:${l.weight}>`)
        .join(', ');
    return `${basePrompt}\n${loraPrompts}`;
});

function handleLoraClick(lora) {
    globalState.openLoraDetail(lora);
}

async function copyPrompt() {
    await navigator.clipboard.writeText(formattedPrompt.value);
    showCopySuccess.value = true;
    setTimeout(() => showCopySuccess.value = false, 2000);
}
</script>

<template>
    <Transition name="fade">
        <div v-if="show" class="combine-detail-overlay" @click="$emit('close')">
            <div class="detail-card" @click.stop>
                <h2>{{ combination.name }}</h2>
                
                <div class="loras-section">
                    <h3>组成的Lora:</h3>
                    <div class="lora-list">
                        <button v-for="lora in combination.loras" 
                                :key="lora.name"
                                @click="handleLoraClick(lora)"
                                class="lora-item">
                            {{ lora.name }} ({{ lora.weight }})
                        </button>
                    </div>
                </div>

                <div class="prompt-section">
                    <h3>提示词:</h3>
                    <div class="prompt-content">{{ formattedPrompt }}</div>
                    <button @click="copyPrompt" 
                            :class="{ success: showCopySuccess }">
                        {{ showCopySuccess ? '已复制!' : '复制' }}
                    </button>
                </div>

                <div class="note-section">
                    <h3>备注:</h3>
                    <div class="note-content">{{ combination.note }}</div>
                </div>
            </div>
        </div>
    </Transition>
</template>

<style scoped>
/* ...styles... */
</style>
