<script setup>
import { defineProps, defineEmits, ref } from 'vue';

const props = defineProps({
    previews: {
        type: Array,
        required: true
    },
    currentPreviewIndex: {
        type: Number,
        required: true
    },
    lora: {
        type: Object,
        required: true
    }
});

const emit = defineEmits(['previous', 'next', 'toggleUpload', 'setAsMain', 'imageClick']);

function handleImageClick() {
    emit('imageClick', props.previews[props.currentPreviewIndex]);
}
</script>

<template>
    <div class="preview-section">
        <div v-if="previews.length > 0 || lora.has_preview" class="preview-container">
            <div class="image-wrapper" @click="handleImageClick">
                <img :src="`http://localhost:5000${previews[currentPreviewIndex] || lora.preview_path}`"
                    :alt="lora.name" class="preview-image" />
            </div>
            <div class="controls-wrapper">
                <div class="preview-controls">
                    <button @click="$emit('previous')" :disabled="currentPreviewIndex === 0" class="nav-btn">
                        ←
                    </button>
                    <button @click="$emit('toggleUpload')" class="add-btn">
                        +
                    </button>
                    <button v-if="currentPreviewIndex > 0" @click="$emit('setAsMain')" class="set-main-btn">
                        ★
                    </button>
                    <button @click="$emit('next')" :disabled="currentPreviewIndex === previews.length - 1"
                        class="nav-btn">
                        →
                    </button>
                </div>
            </div>
        </div>
        <div v-else class="no-preview">
            <div class="no-preview-text">无预览图</div>
            <div class="controls-wrapper">
                <button @click="$emit('toggleUpload')" class="add-btn">+</button>
            </div>
        </div>
    </div>
</template>

<style scoped>
.preview-section {
    flex: 1;
    max-width: 50%;
    display: flex;
    flex-direction: column;
}

.preview-container {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

.image-wrapper {
    width: 100%;
    display: flex;
    justify-content: center;
    align-items: center;
    background: #f8f9fa;
    border-radius: 8px;
}

.preview-image {
    max-width: 100%;
    max-height: 400px;
    object-fit: contain;
}

.controls-wrapper {
    display: flex;
    justify-content: center;
    padding: 0.5rem;
}

.preview-controls {
    display: flex;
    gap: 1.5rem;
    align-items: center;
    padding: 1rem 0;
}

.nav-btn,
.add-btn,
.set-main-btn {
    position: relative;
    border: none;
    padding: 0.8rem 1.2rem;
    border-radius: 8px;
    cursor: pointer;
    font-size: 1.2rem;
    transition: all 0.3s ease;
    overflow: visible;
}

.nav-btn {
    background: linear-gradient(135deg, #2196f3, #1976d2);
    color: white;
    min-width: 3rem;
}

.add-btn {
    background: linear-gradient(135deg, #4caf50, #388e3c);
    color: white;
    min-width: 3rem;
}

.set-main-btn {
    background: linear-gradient(135deg, #ffd700, #ffa000);
    color: white;
    min-width: 3rem;
}

.nav-btn:hover:not(:disabled),
.add-btn:hover,
.set-main-btn:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
}

.nav-btn:active:not(:disabled),
.add-btn:active,
.set-main-btn:active {
    transform: translateY(0);
}

.nav-btn:disabled {
    background: #ccc;
    cursor: not-allowed;
    transform: none;
}

.no-preview {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    align-items: center;
    padding: 2rem;
    background: #f8f9fa;
    border-radius: 8px;
}

.no-preview-text {
    color: #666;
}
</style>
