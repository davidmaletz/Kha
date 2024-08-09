package kha.graphics4;

import kha.arrays.Uint32Array;

@:headerCode("
#include <kinc/graphics4/indexbuffer.h>
")
@:headerClassCode("kinc_g4_index_buffer_t buffer;")
class IndexBuffer {
	var data: Uint32Array;
	var myCount: Int;

	public function new(indexCount: Int, usage: Usage, canRead: Bool = false) {
		myCount = indexCount;
		data = new Uint32Array(0);
		untyped __cpp__("kinc_g4_index_buffer_init(&buffer, indexCount, KINC_G4_INDEX_BUFFER_FORMAT_32BIT, (kinc_g4_usage_t)usage);");
		SystemImpl.graphicsBytes += byteSize();
	}
    	public inline function byteSize():Int {return myCount*4;}
	public function delete(): Void {
		SystemImpl.graphicsBytes -= byteSize(); untyped __cpp__("kinc_g4_index_buffer_destroy(&buffer);");
	}

	@:functionCode("
		data->self.data = (uint8_t*)kinc_g4_index_buffer_lock(&buffer, start, count);
		data->byteArrayLength = count * 4;
		data->byteArrayOffset = 0;
		return data;
	")
	function lockPrivate(start: Int, count: Int): Uint32Array {
		return data;
	}

	public function lock(?start: Int, ?count: Int): Uint32Array {
		if (start == null)
			start = 0;
		if (count == null)
			count = this.count();
		return lockPrivate(start, count);
	}

	@:functionCode("kinc_g4_index_buffer_unlock(&buffer, count); data->self.data = nullptr;")
	public function unlockPrivate(count: Int): Void {}

	public function unlock(?count: Int): Void {
		if (count == null)
			count = this.count();
		unlockPrivate(count);
	}

	public function count(): Int {
		return myCount;
	}
}
