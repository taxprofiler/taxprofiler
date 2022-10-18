//
// Process long raw reads with porechop
//

include { FASTQC as FASTQC_PROCESSED } from '../../modules/nf-core/fastqc/main'
include { FALCO as FALCO_PROCESSED   } from '../../modules/nf-core/falco/main'

include { PORECHOP                   } from '../../modules/nf-core/porechop/main'
include { FILTLONG                   } from '../../modules/nf-core/filtlong/main'

workflow LONGREAD_PREPROCESSING {
    take:
    reads

    main:
    ch_versions      = Channel.empty()
    ch_multiqc_files = Channel.empty()

    if ( !params.longread_qc_skipadaptertrim && params.longread_qc_skipqualityfilter) {
        PORECHOP ( reads )

        ch_processed_reads = PORECHOP.out.reads
                                        .map {
                                                meta, reads ->
                                                def meta_new = meta.clone()
                                                meta_new['single_end'] = 1
                                                [ meta_new, reads ]
                                        }

        ch_versions = ch_versions.mix(PORECHOP.out.versions.first())
        ch_multiqc_files = ch_multiqc_files.mix( PORECHOP.out.log )

    } else if ( params.longread_qc_skipadaptertrim && !params.longread_qc_skipqualityfilter) {

        ch_processed_reads = FILTLONG ( reads.map{ meta, reads -> [meta, [], reads ]} )
        ch_versions = ch_versions.mix(FILTLONG.out.versions.first())
        ch_multiqc_files = ch_multiqc_files.mix( FILTLONG.out.log )

    } else {
        PORECHOP ( reads )
        ch_clipped_reads = PORECHOP.out.reads
                                        .map {
                                                meta, reads ->
                                                def meta_new = meta.clone()
                                                meta_new['single_end'] = 1
                                                [ meta_new, reads ]
                                        }

        ch_processed_reads = FILTLONG ( ch_clipped_reads.map{ meta, reads -> [meta, [], reads ]} ).reads

        ch_versions = ch_versions.mix(PORECHOP.out.versions.first())
        ch_versions = ch_versions.mix(FILTLONG.out.versions.first())
        ch_multiqc_files = ch_multiqc_files.mix( PORECHOP.out.log )
        ch_multiqc_files = ch_multiqc_files.mix( FILTLONG.out.log )
    }

    if (params.perform_fastqc_alternative) {
        FALCO_PROCESSED ( ch_processed_reads )
        ch_multiqc_files = ch_multiqc_files.mix( FALCO_PROCESSED.out.txt )

    } else {
        FASTQC_PROCESSED ( ch_processed_reads )
        ch_multiqc_files = ch_multiqc_files.mix( FASTQC_PROCESSED.out.zip )
    }

    emit:
    reads    = ch_processed_reads   // channel: [ val(meta), [ reads ] ]
    versions = ch_versions          // channel: [ versions.yml ]
    mqc      = ch_multiqc_files
}

