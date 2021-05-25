#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

// Download image cubes from CASDA
process casda_download {
    container = params.WALLABY_SCRIPTS

    input:
        val sbid

    output:
        stdout emit: cube

    script:
        """
        python3 -u /app/download.py \
            -i $sbid \
            -o ${params.WORKDIR} \
            -u ${params.CASDA_USERNAME} \
            -p ${params.CASDA_PASSWORD} \
            -ct ${params.CASDA_CUBE_TYPE} \
            -cf ${params.CASDA_CUBE_FILENAME} \
            -wt ${params.CASDA_WEIGHTS_TYPE} \
            -wf ${params.CASDA_WEIGHTS_FILENAME}
        """
}

// Checksum comparison
process checksum {
    container = params.WALLABY_SCRIPTS

    input:
        val cube

    output:
        stdout emit: cube

    script:
        """
        python3 -u /app/verify_checksum.py $cube
        """
}

// Generate configuration
process generate_config {
    container = params.WALLABY_SCRIPTS

    input:
        val cubes

    output:
        stdout emit: linmos_config

    script:
        """
        python3 -u /app/generate_linmos_config.py \
            -i "$cubes" \
            -f ${params.WORKDIR}/${params.LINMOS_OUTPUT_IMAGE_CUBE} \
            -c ${params.WORKDIR}/${params.LINMOS_CONFIG_FILENAME}
        """
}

// Linear mosaicking
// TODO(austin): emit mosaicked cube location
process linmos {
    container = "aussrc/yandasoft_devel_focal:latest"
    clusterOptions = params.LINMOS_CLUSTER_OPTIONS

    input:
        val linmos_config
    
    output:
        val "${params.WORKDIR}/${params.LINMOS_OUTPUT_IMAGE_CUBE}", emit: cube_file

    script:
        """
        #!/bin/bash
        mpirun linmos-mpi -c $linmos_config
        """
}

// TODO(austin): statistical check of mosaicked cube

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow {
    sbids = Channel.of(params.SBIDS.split(','))

    main:
        casda_download(sbids)
        checksum(casda_download.out.cube)
        generate_config(checksum.out.cube.collect())
        linmos(generate_config.out.linmos_config)
}

// ----------------------------------------------------------------------------------------

// #!/usr/bin/env nextflow

// nextflow.enable.dsl = 2
// include { mosaicking } from './mosaicking/main'
// include { source_extraction } from './source_extraction/main'

// /* Requires the following input parameters (minimum):

// - SBIDS
// - WORKDIR
// - CASDA_USERNAME
// - CASDA_PASSWORD
// */

// workflow {
//     sbids = Channel.of(params.SBIDS.split(','))

//     main: 
//         mosaicking(sbids)
//         source_extraction(mosaicking.out.cube)  
// }