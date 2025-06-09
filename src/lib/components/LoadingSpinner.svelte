<script lang="ts">
	let { 
		size = 'md', 
		color = 'primary', 
		text,
		center = false 
	}: {
		size?: 'sm' | 'md' | 'lg';
		color?: 'primary' | 'white' | 'gray';
		text?: string;
		center?: boolean;
	} = $props();

	function getSizeClasses(size: string): string {
		switch (size) {
			case 'sm':
				return 'h-4 w-4';
			case 'lg':
				return 'h-8 w-8';
			default:
				return 'h-6 w-6';
		}
	}

	function getColorClasses(color: string): string {
		switch (color) {
			case 'white':
				return 'border-white';
			case 'gray':
				return 'border-gray-300';
			default:
				return 'border-indigo-600';
		}
	}

	let spinnerClasses = $derived(`animate-spin rounded-full border-b-2 ${getSizeClasses(size)} ${getColorClasses(color)}`);
	let containerClasses = $derived(center ? 'flex items-center justify-center' : 'flex items-center');
</script>

<div class={containerClasses}>
	<div class={spinnerClasses}></div>
	{#if text}
		<span class="ml-2 text-sm text-gray-600">{text}</span>
	{/if}
</div>