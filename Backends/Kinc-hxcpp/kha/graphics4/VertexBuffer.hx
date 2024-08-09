package kha.graphics4;

import kha.arrays.Float32Array;
import kha.arrays.Int16Array;
import kha.graphics4.VertexData;
import kha.graphics4.VertexElement;
import kha.graphics4.VertexStructure;

@:headerCode("
#include <kinc/graphics4/vertexbuffer.h>
#include <khalib/g4.h>
")
@:headerClassCode("kinc_g4_vertex_buffer_t buffer;")
class VertexBuffer {
	var data: Float32Array; private var byteSize:Int;
	@:keep var dataInt16: Int16Array;

	public function new(vertexCount: Int, structure: VertexStructure, usage: Usage, instanceDataStepRate: Int = 0, canRead: Bool = false) {
		byteSize = vertexCount*structure.byteSize(); init(vertexCount, structure, usage, instanceDataStepRate);
		data = new Float32Array(0);
	}

	public function delete(): Void {
	        if(byteSize == 0) trace("Warning: VBO double delete!"); SystemImpl.graphicsBytes -= byteSize; byteSize = 0;
		untyped __cpp__("kinc_g4_vertex_buffer_destroy(&buffer);");
	}

	@:functionCode("
		kinc_g4_vertex_structure_t structure2;
		kinc_g4_vertex_structure_init(&structure2);
		for (int i = 0; i < structure->size(); ++i) {
			kinc_g4_vertex_data_t data = kha_convert_vertex_data(structure->get(i)->data);
			kinc_g4_vertex_structure_add(&structure2, structure->get(i)->name, data);
		}
		kinc_g4_vertex_buffer_init(&buffer, vertexCount, &structure2, (kinc_g4_usage_t)usage, instanceDataStepRate);
	")
	function init(vertexCount: Int, structure: VertexStructure, usage: Int, instanceDataStepRate: Int) {SystemImpl.graphicsBytes += byteSize;}

	@:functionCode("
		data->self.data = (uint8_t*)kinc_g4_vertex_buffer_lock(&buffer, start, count);
		data->byteArrayLength = count * kinc_g4_vertex_buffer_stride(&buffer);
		data->byteArrayOffset = 0;
		return data;
	")
	function lockPrivate(start: Int, count: Int): Float32Array {
		return data;
	}

	var lastLockCount: Int = 0;

	public function lock(?start: Int, ?count: Int): Float32Array {
		if (start == null)
			start = 0;
		if (count == null)
			count = this.count() - start;
		lastLockCount = count;
		return lockPrivate(start, count);
	}

	@:functionCode("
		dataInt16->self.data = (uint8_t*)kinc_g4_vertex_buffer_lock(&buffer, start, count);
		dataInt16->byteArrayLength = count * kinc_g4_vertex_buffer_stride(&buffer);
		dataInt16->byteArrayOffset = 0;
		return dataInt16;
	")
	function lockInt16Private(start: Int, count: Int): Int16Array {
		return dataInt16;
	}

	public function lockInt16(?start: Int, ?count: Int): Int16Array {
		if (start == null)
			start = 0;
		if (count == null)
			count = this.count();
		lastLockCount = count;
		if (dataInt16 == null)
			dataInt16 = new Int16Array(0);
		return lockInt16Private(start, count);
	}

	@:functionCode("kinc_g4_vertex_buffer_unlock(&buffer, count); data->self.data = nullptr; if (!hx::IsNull(dataInt16)) dataInt16->self.data = nullptr;")
	function unlockPrivate(count: Int): Void {}

	public function unlock(?count: Int): Void {
		unlockPrivate(count == null ? lastLockCount : count);
	}

	@:functionCode("return kinc_g4_vertex_buffer_stride(&buffer);")
	public function stride(): Int {
		return 0;
	}

	@:functionCode("return kinc_g4_vertex_buffer_count(&buffer);")
	public function count(): Int {
		return 0;
	}

	@:noCompletion
	@:keep
	public static function _unused1(): VertexElement {
		return null;
	}

	@:noCompletion
	@:keep
	public static function _unused2(): VertexData {
		return VertexData.Float32_1X;
	}
}
