//  Copyright (C) 2016 Rumen G. Bogdanovski
//  All rights reserved.
//
//	You can use this software under the terms of 'INDIGO Astronomy
//  open-source license' (see LICENSE.md).
//
//	THIS SOFTWARE IS PROVIDED BY THE AUTHORS 'AS IS' AND ANY EXPRESS
//	OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//	ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
//	DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//	DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
//	GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
//	NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

//  version history
//  2.0 Build 0 - PoC by Rumen G. Bogdanovski

/** INDIGO ASI filter wheel driver main
 \file indigo_wheel_asi_main.c
 */

#include <stdio.h>
#include <string.h>

#include "indigo_driver_xml.h"

#include "indigo_wheel_asi.h"

int main(int argc, const char * argv[]) {
	indigo_main_argc = argc;
	indigo_main_argv = argv;
	indigo_client *protocol_adapter = indigo_xml_device_adapter(0, 1);
	indigo_start();
	indigo_wheel_asi(true);
	indigo_attach_client(protocol_adapter);
	indigo_xml_parse(0, NULL, protocol_adapter);
	indigo_wheel_asi(false);
	indigo_stop();
	return 0;
}
