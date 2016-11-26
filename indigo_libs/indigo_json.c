// Copyright (c) 2016 CloudMakers, s. r. o.
// All rights reserved.
//
// You can use this software under the terms of 'INDIGO Astronomy
// open-source license' (see LICENSE.md).
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHORS 'AS IS' AND ANY EXPRESS
// OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// version history
// 2.0 Build 0 - PoC by Peter Polakovic <peter.polakovic@cloudmakers.eu>

/** INDIGO JSON wire protocol parser
 \file indigo_json.c
 */

#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <stdio.h>
#include <unistd.h>
#include <ctype.h>
#include <pthread.h>
#include <assert.h>
#include <stdint.h>

#include "indigo_json.h"

//#undef INDIGO_TRACE_PROTOCOL
//#define INDIGO_TRACE_PROTOCOL(c) c

static pthread_mutex_t json_mutex = PTHREAD_MUTEX_INITIALIZER;

static bool full_write(int handle, const char *buffer, long length) {
	long remains = length;
	while (true) {
		long bytes_written = write(handle, buffer, remains);
		if (bytes_written < 0)
			return false;
		if (bytes_written == remains)
			return true;
		buffer += bytes_written;
		remains -= bytes_written;
	}
}

static void ws_write(int handle, const char *buffer, long length) {
	uint8_t header[10] = { 0x81 };
	if (length <= 0x7D) {
		header[1] = length;
		full_write(handle, (char *)header, 2);
	} else if (length <= 0xFFFF) {
		header[1] = 0x7E;
		uint16_t payloadLength = htons(length);
		memcpy(header+2, &payloadLength, 2);
		full_write(handle, (char *)header, 4);
	} else {
		header[1] = 0x7F;
		uint64_t payloadLength = htonll(length);
		memcpy(header+2, &payloadLength, 8);
		full_write(handle, (char *)header, 10);
	}
	full_write(handle, buffer, length);
}

static bool full_read(int handle, char *buffer, long length) {
	long remains = length;
	while (true) {
		long bytes_read = read(handle, buffer, remains);
		if (bytes_read <= 0) {
			indigo_trace("full_read failed");
			return false;
		}
		if (bytes_read == remains) {
			indigo_trace("full_read ok");
			return true;
		}
		buffer += bytes_read;
		remains -= bytes_read;
	}
}

static long ws_read(int handle, char *buffer, long length) {
	uint8_t header[14];
	if (!full_read(handle, (char *)header, 6))
		return -1;
	indigo_trace("ws_read -> %2x", header[0]);
	uint8_t *masking_key = header+2;
	uint64_t payload_length = header[1] & 0x7F;
	if (payload_length == 0x7E) {
		if (!full_read(handle, (char *)header + 6, 2))
			return -1;
		masking_key = header + 4;
		payload_length = ntohs(*((uint16_t *)(header+2)));
	} else if (payload_length == 0x7F) {
		if (!full_read(handle, (char *)header + 6, 8))
			return -1;
		masking_key = header+10;
		payload_length = ntohll(*((uint64_t *)(header+2)));
	}
	if (length < payload_length)
		return -1;
	if (!full_read(handle, buffer, payload_length))
		return -1;
	for (uint64_t i = 0; i < payload_length; i++) {
		buffer[i] ^= masking_key[i%4];
	}
	return payload_length;
}

static long stream_read(int handle, char *buffer, int length) {
	int i = 0;
	char c = '\0';
	long n = 0;
	while (i < length) {
		n = read(handle, &c, 1);
		if (n > 0 && c != '\r' && c != '\n') {
			buffer[i++] = c;
		} else {
			break;
		}
	}
	buffer[i] = '\0';
	return n == -1 ? -1 : i;
}

static indigo_result json_define_property(indigo_client *client, struct indigo_device *device, indigo_property *property, const char *message) {
	assert(device != NULL);
	assert(client != NULL);
	assert(property != NULL);
	if (client->version == INDIGO_VERSION_NONE)
		return INDIGO_OK;
	pthread_mutex_lock(&json_mutex);
	indigo_adapter_context *client_context = (indigo_adapter_context *)client->client_context;
	assert(client_context != NULL);
	int handle = client_context->output;
	char output_buffer[JSON_BUFFER_SIZE];
	char *pnt = output_buffer;
	int size;
	switch (property->type) {
		case INDIGO_TEXT_VECTOR:
			size = sprintf(pnt, "{ \"defTextVector\": { \"version\": %d, \"device\": \"%s\", \"name\": \"%s\", \"group\": \"%s\", \"label\": \"%s\", \"perm\": \"%s\", \"state\": \"%s\"", property->version, property->device, property->name, property->group, property->label, indigo_property_perm_text[property->perm], indigo_property_state_text[property->state]);
			pnt += size;
			if (message) {
				size = sprintf(pnt, ", \"message\": \"%s\", \"defText\": [ ", message);
				pnt += size;
			} else {
				size = sprintf(pnt, ", \"defText\": [ ");
				pnt += size;
			}
			for (int i = 0; i < property->count; i++) {
				indigo_item *item = &property->items[i];
				size = sprintf(pnt, "%s { \"name\": \"%s\", \"label\": \"%s\", \"value\": \"%s\" }",  i > 0 ? "," : "", item->name, item->label, item->text.value);
				pnt += size;
			}
			size = sprintf(pnt, " ] } }");
			size += pnt - output_buffer;
			break;
		case INDIGO_NUMBER_VECTOR:
			size = sprintf(pnt, "{ \"defNumberVector\": { \"version\": %d, \"device\": \"%s\", \"name\": \"%s\", \"group\": \"%s\", \"label\": \"%s\", \"perm\": \"%s\", \"state\": \"%s\"", property->version, property->device, property->name, property->group, property->label, indigo_property_perm_text[property->perm], indigo_property_state_text[property->state]);
			pnt += size;
			if (message) {
				size = sprintf(pnt, ", \"message\": \"%s\", \"defNumber\": [ ", message);
				pnt += size;
			} else {
				size = sprintf(pnt, ", \"defNumber\": [ ");
				pnt += size;
			}
			for (int i = 0; i < property->count; i++) {
				indigo_item *item = &property->items[i];
				size = sprintf(pnt, "%s { \"name\": \"%s\", \"label\": \"%s\", \"min\": %g, \"max\": %g, \"step\": %g, \"value\": %g }",  i > 0 ? "," : "", item->name, item->label, item->number.min, item->number.max, item->number.step, item->number.value);
				pnt += size;
			}
			size = sprintf(pnt, " ] } }");
			size += pnt - output_buffer;
			break;
		case INDIGO_SWITCH_VECTOR:
			size = sprintf(pnt, "{ \"defSwitchVector\": { \"version\": %d, \"device\": \"%s\", \"name\": \"%s\", \"group\": \"%s\", \"label\": \"%s\", \"perm\": \"%s\", \"state\": \"%s\", \"rule\": \"%s\"", property->version, property->device, property->name, property->group, property->label, indigo_property_perm_text[property->perm], indigo_property_state_text[property->state], indigo_switch_rule_text[property->rule]);
			pnt += size;
			if (message) {
				size = sprintf(pnt, ", \"message\": \"%s\", \"defSwitch\": [ ", message);
				pnt += size;
			} else {
				size = sprintf(pnt, ", \"defSwitch\": [ ");
				pnt += size;
			}
			for (int i = 0; i < property->count; i++) {
				indigo_item *item = &property->items[i];
				size = sprintf(pnt, "%s { \"name\": \"%s\", \"label\": \"%s\", \"value\": %s }",  i > 0 ? "," : "", item->name, item->label, item->sw.value ? "true" : "false");
				pnt += size;
			}
			size = sprintf(pnt, " ] } }");
			size += pnt - output_buffer;
			break;
		case INDIGO_LIGHT_VECTOR:
			size = sprintf(pnt, "{ \"defLightVector\": { \"version\": %d, \"device\": \"%s\", \"name\": \"%s\", \"group\": \"%s\", \"label\": \"%s\", \"state\": \"%s\"", property->version, property->device, property->name, property->group, property->label, indigo_property_state_text[property->state]);
			pnt += size;
			if (message) {
				size = sprintf(pnt, ", \"message\": \"%s\", \"defLight\": [ ", message);
				pnt += size;
			} else {
				size = sprintf(pnt, ", \"defLight\": [ ");
				pnt += size;
			}
			for (int i = 0; i < property->count; i++) {
				indigo_item *item = &property->items[i];
				size = sprintf(pnt, "%s { \"name\": \"%s\", \"label\": \"%s\", \"value\": \"%s\" }",  i > 0 ? "," : "", item->name, item->label, indigo_property_state_text[item->light.value]);
				pnt += size;
			}
			size = sprintf(pnt, " ] } }");
			size += pnt - output_buffer;
			break;
		case INDIGO_BLOB_VECTOR:
			size = sprintf(pnt, "{ \"defBLOBVector\": { \"version\": %d, \"device\": \"%s\", \"name\": \"%s\", \"group\": \"%s\", \"label\": \"%s\", \"state\": \"%s\"", property->version, property->device, property->name, property->group, property->label, indigo_property_state_text[property->state]);
			pnt += size;
			if (message) {
				size = sprintf(pnt, ", \"message\": \"%s\", \"defBLOB\": [ ", message);
				pnt += size;
			} else {
				size = sprintf(pnt, ", \"defBLOB\": [ ");
				pnt += size;
			}
			for (int i = 0; i < property->count; i++) {
				indigo_item *item = &property->items[i];
				size = sprintf(pnt, "%s { \"name\": \"%s\", \"label\": \"%s\" }", i > 0 ? "," : "", item->name, item->label);
				pnt += size;
			}
			size = sprintf(pnt, " ] } }");
			size += pnt - output_buffer;
			break;
	}
	if (client_context->web_socket)
		ws_write(handle, output_buffer, size);
	else
		write(handle, output_buffer, size);
	INDIGO_TRACE_PROTOCOL(indigo_trace("sent: %s\n", output_buffer));
	pthread_mutex_unlock(&json_mutex);
	return INDIGO_OK;
}

static indigo_result json_update_property(indigo_client *client, struct indigo_device *device, indigo_property *property, const char *message) {
	assert(device != NULL);
	assert(client != NULL);
	assert(property != NULL);
	if (client->version == INDIGO_VERSION_NONE)
		return INDIGO_OK;
	pthread_mutex_lock(&json_mutex);
	indigo_adapter_context *client_context = (indigo_adapter_context *)client->client_context;
	assert(client_context != NULL);
	int handle = client_context->output;
	char output_buffer[JSON_BUFFER_SIZE];
	char *pnt = output_buffer;
	int size;
	switch (property->type) {
		case INDIGO_TEXT_VECTOR:
			size = sprintf(pnt, "{ \"setTextVector\": { \"device\": \"%s\", \"name\": \"%s\", \"state\": \"%s\"", property->device, property->name, indigo_property_state_text[property->state]);
			pnt += size;
			if (message) {
				size = sprintf(pnt, ", \"message\": \"%s\", \"setText\": [ ", message);
				pnt += size;
			} else {
				size = sprintf(pnt, ", \"setText\": [ ");
				pnt += size;
			}
			for (int i = 0; i < property->count; i++) {
				indigo_item *item = &property->items[i];
				size = sprintf(pnt, "%s { \"name\": \"%s\", \"value\": \"%s\" }",  i > 0 ? "," : "", item->name, item->text.value);
				pnt += size;
			}
			size = sprintf(pnt, " ] } }");
			size += pnt - output_buffer;
			break;
		case INDIGO_NUMBER_VECTOR:
			size = sprintf(pnt, "{ \"setNumberVector\": { \"device\": \"%s\", \"name\": \"%s\", \"state\": \"%s\"", property->device, property->name, indigo_property_state_text[property->state]);
			pnt += size;
			if (message) {
				size = sprintf(pnt, ", \"message\": \"%s\", \"setNumber\": [ ", message);
				pnt += size;
			} else {
				size = sprintf(pnt, ", \"setNumber\": [ ");
				pnt += size;
			}
			for (int i = 0; i < property->count; i++) {
				indigo_item *item = &property->items[i];
				size = sprintf(pnt, "%s { \"name\": \"%s\", \"value\": %g }",  i > 0 ? "," : "", item->name, item->number.value);
				pnt += size;
			}
			size = sprintf(pnt, " ] } }");
			size += pnt - output_buffer;
			break;
		case INDIGO_SWITCH_VECTOR:
			size = sprintf(pnt, "{ \"setSwitchVector\": { \"device\": \"%s\", \"name\": \"%s\", \"state\": \"%s\"", property->device, property->name, indigo_property_state_text[property->state]);
			pnt += size;
			if (message) {
				size = sprintf(pnt, ", \"message\": \"%s\", \"setSwitch\": [ ", message);
				pnt += size;
			} else {
				size = sprintf(pnt, ", \"setSwitch\": [ ");
				pnt += size;
			}
			for (int i = 0; i < property->count; i++) {
				indigo_item *item = &property->items[i];
				size = sprintf(pnt, "%s { \"name\": \"%s\", \"value\": %s }",  i > 0 ? "," : "", item->name, item->sw.value ? "true" : "false");
				pnt += size;
			}
			size = sprintf(pnt, " ] } }");
			size += pnt - output_buffer;
			break;
		case INDIGO_LIGHT_VECTOR:
			size = sprintf(pnt, "{ \"setLightVector\": { \"device\": \"%s\", \"name\": \"%s\", \"state\": \"%s\"", property->device, property->name, indigo_property_state_text[property->state]);
			pnt += size;
			if (message) {
				size = sprintf(pnt, ", \"message\": \"%s\", \"setLight\": [ ", message);
				pnt += size;
			} else {
				size = sprintf(pnt, ", \"setLight\": [ ");
				pnt += size;
			}
			for (int i = 0; i < property->count; i++) {
				indigo_item *item = &property->items[i];
				size = sprintf(pnt, "%s { \"name\": \"%s\", \"value\": \"%s\" }",  i > 0 ? "," : "", item->name, indigo_property_state_text[item->light.value]);
				pnt += size;
			}
			size = sprintf(pnt, " ] }");
			size += pnt - output_buffer;
			break;
		case INDIGO_BLOB_VECTOR:
			size = sprintf(pnt, "{ \"setBLOBVector\": { \"device\": \"%s\", \"name\": \"%s\", \"state\": \"%s\"", property->device, property->name, indigo_property_state_text[property->state]);
			pnt += size;
			if (message) {
				size = sprintf(pnt, ", \"message\": \"%s\", \"setBLOB\": [ ", message);
				pnt += size;
			} else {
				size = sprintf(pnt, ", \"items\": [ ");
				pnt += size;
			}
			for (int i = 0; i < property->count; i++) {
				indigo_item *item = &property->items[i];
				size = sprintf(pnt, "%s { \"name\": \"%s\" }", i > 0 ? "," : "", item->name);
				pnt += size;
			}
			size = sprintf(pnt, " ] }");
			size += pnt - output_buffer;
			break;
	}
	if (client_context->web_socket)
		ws_write(handle, output_buffer, size);
	else
		write(handle, output_buffer, size);
	INDIGO_TRACE_PROTOCOL(indigo_trace("sent: %s\n", output_buffer));
	pthread_mutex_unlock(&json_mutex);
	return INDIGO_OK;
}

static indigo_result json_delete_property(indigo_client *client, struct indigo_device *device, indigo_property *property, const char *message) {
	assert(device != NULL);
	assert(client != NULL);
	assert(property != NULL);
	if (client->version == INDIGO_VERSION_NONE)
		return INDIGO_OK;
	pthread_mutex_lock(&json_mutex);
	indigo_adapter_context *client_context = (indigo_adapter_context *)client->client_context;
	assert(client_context != NULL);
	int handle = client_context->output;
	char output_buffer[JSON_BUFFER_SIZE];
	char *pnt = output_buffer;
	int size = sprintf(pnt, "{ \"deleteProperty\": { \"device\": \"%s\", \"name\": \"%s\"", property->device, property->name);
	pnt += size;
	if (message) {
		size = sprintf(pnt, ", \"message\": \"%s\" } }", message);
	} else {
		size = sprintf(pnt, " } }");
	}
	size += pnt - output_buffer;
	if (client_context->web_socket)
		ws_write(handle, output_buffer, size);
	else
		write(handle, output_buffer, size);
	INDIGO_TRACE_PROTOCOL(indigo_trace("sent: %s\n", output_buffer));
	pthread_mutex_unlock(&json_mutex);
	return INDIGO_OK;
}

static indigo_result json_message_property(indigo_client *client, struct indigo_device *device, const char *message) {
	assert(device != NULL);
	assert(client != NULL);
	pthread_mutex_lock(&json_mutex);
	indigo_adapter_context *client_context = (indigo_adapter_context *)client->client_context;
	assert(client_context != NULL);
	int handle = client_context->output;
	char output_buffer[JSON_BUFFER_SIZE];
	char *pnt = output_buffer;
	int size = sprintf(pnt, "{ \"message\": \"%s\" }", message);
	if (client_context->web_socket)
		ws_write(handle, output_buffer, size);
	else
		write(handle, output_buffer, size);
	INDIGO_TRACE_PROTOCOL(indigo_trace("sent: %s\n", output_buffer));
	pthread_mutex_unlock(&json_mutex);
	return INDIGO_OK;
}

static indigo_result json_detach(indigo_client *client) {
	assert(client != NULL);
	indigo_adapter_context *client_context = (indigo_adapter_context *)client->client_context;
	close(client_context->input);
	close(client_context->output);
	return INDIGO_OK;
}

indigo_client *indigo_json_device_adapter(int input, int ouput, bool web_socket) {
	static indigo_client client_template = {
		"", NULL, INDIGO_OK, INDIGO_VERSION_NONE, INDIGO_ENABLE_BLOB_ALSO,
		NULL,
		json_define_property,
		json_update_property,
		json_delete_property,
		json_message_property,
		json_detach,

	};
	indigo_client *client = malloc(sizeof(indigo_client));
	assert(client != NULL);
	memcpy(client, &client_template, sizeof(indigo_client));
	indigo_adapter_context *client_context = malloc(sizeof(indigo_adapter_context));
	assert(client_context != NULL);
	client_context->input = input;
	client_context->output = ouput;
	client_context->web_socket = web_socket;
	client->client_context = client_context;
	return client;
}

void indigo_json_parse(indigo_device *device, indigo_client *client) {
	indigo_adapter_context *context = (indigo_adapter_context*)client->client_context;
	int input = context->input;
	char buffer[JSON_BUFFER_SIZE];
	while (true) {
		long size = context->web_socket ? ws_read(input, buffer, JSON_BUFFER_SIZE) : stream_read(input, buffer, JSON_BUFFER_SIZE);
		if (size == -1)
			break;
		
		buffer[size] = 0;
		indigo_log("%s", buffer);
		if (client->version == INDIGO_VERSION_NONE) {
			client->version = INDIGO_VERSION_CURRENT;
			indigo_enumerate_properties(client, &INDIGO_ALL_PROPERTIES);
		}
	}
}