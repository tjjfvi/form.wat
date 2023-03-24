(module
  ;; (import "log" "brk" (func $log_brk))
  ;; (import "log" "u32" (func $log_u32 (param i32)))
  ;; (import "log" "stre" (func $log_stre (param i32) (param i32)))
  ;; (func $dbg_u32 (param $v i32) (result i32) local.get $v call $log_u32 local.get $v)
  ;; (func $log_strl (param $s i32) (param $l i32) local.get $s local.get $s local.get $l i32.add call $log_strl)

  (memory 128)
  (export "memory" (memory 0))

  (global $buffer_size i32 (i32.const 4096))

  (global $shared_start (mut i32) (i32.const 4096))
  (global $shared_idx (mut i32) (i32.const 4096))

  (global $global_config_start (mut i32) (i32.const 0))
  (global $global_config_len (mut i32) (i32.const 0))

  (global $plugin_config_start (mut i32) (i32.const 0))
  (global $plugin_config_len (mut i32) (i32.const 0))

  (global $input_start (mut i32) (i32.const 0))
  (global $input_len (mut i32) (i32.const 0))

  (global $output_start (mut i32) (i32.const 0))
  (global $output_len (mut i32) (i32.const 0))

  (global $indent_width (mut i32) (i32.const 2))
  (global $indent_char (mut i32) (i32.const 32))
  (global $indent_len (mut i32) (i32.const 2))

  (data $error_string_newline "newline in string")
  (global $error_string_newline_len i32 (i32.const 17))

  (func $format (result i32)
    (local $read_idx i32)
    (local $read_end i32)
    (local $write_idx i32)
    (local $byte i32)

    (local $indent i32)
    (local $in_ident i32)
    (local $space_count i32)
    (local $was_newline i32)
    (local $depth i32)
    (local $in_comment i32)
    (local $multi_comment i32)
    (local $in_str i32)

    (local.set $indent (i32.const 0))

    (local.tee $read_idx (global.get $input_start))
    (global.set $output_start (local.tee $write_idx (local.tee $read_end (i32.add (global.get $input_len)))))

    (i32.store8 (i32.const 0) (i32.const 1))

    (loop $a
      (local.set $byte (i32.load8_u (local.get $read_idx)))

      (if (local.get $in_comment) (then
        (if (local.get $multi_comment) (then) (else
          (if (i32.eq (local.get $byte (i32.const 10))) (then
            ;; '\n'
            (local.set $in_comment (i32.const 0))
            (br $a)
          ))
          (if (i32.eq (local.get $byte) (i32.const 32)) (then
            ;; ' '
            (local.set $space_count (i32.add (local.get $space_count) (i32.const 1)))
          ) (else
            (local.set $space_count (i32.const 0))
          ))
          (i32.store8 (local.get $write_idx) (local.get $byte))
          (local.set $write_idx (i32.add (local.get $write_idx) (i32.const 1)))
        ))
      ) (else (if (local.get $in_str) (then
        (if (i32.eq (local.get $byte) (i32.const 10)) (then
          ;; '\n'
          (memory.init $error_string_newline (global.get $output_start) (i32.const 0) (global.get $error_string_newline_len))
          (global.set $output_len (global.get $error_string_newline_len))
          (return (i32.const 2))
        ))

        (i32.store8 (local.get $write_idx) (local.get $byte))
        (local.set $write_idx (i32.add (local.get $write_idx) (i32.const 1)))

        (if (i32.eq (local.get $in_str) (i32.const 2)) (then
          ;; escape sequence
          (local.set $in_str (i32.const 1))
        ) (else
          (if (i32.eq (local.get $byte) (i32.const 92)) (then
            ;; '\'
            (local.set $in_str (i32.const 2))
          ) (else (if (i32.eq (local.get $byte) (i32.const 34)) (then
            ;; '"'
            (local.set $in_str (i32.const 0))
            (i32.store8 (local.get $write_idx) (i32.const 32))
            (local.set $write_idx (i32.add (local.get $write_idx) (i32.const 1)))
            (local.set $space_count (i32.const 1))
            (local.set $was_newline (i32.const 0))
            (local.set $in_ident (i32.const 0))
          ))))
        ))
      ) (else
        (if (i32.eq (local.get $byte) (i32.const 32)) (then
          ;; ' '
          (if (local.get $in_ident) (then
            (i32.store8 (local.get $write_idx) (i32.const 32))
            (local.set $write_idx (i32.add (local.get $write_idx) (i32.const 1)))
            (local.set $in_ident (i32.const 0))
            (local.set $space_count (i32.const 1))
          ))
        ) (else (if (i32.eq (local.get $byte) (i32.const 10)) (then
          ;; '\n'
          (local.set $was_newline (i32.load8_u (local.get $depth)))
          (local.set $indent (i32.add (local.get $indent) (i32.eq (local.get $was_newline) (i32.const 0))))
          (i32.store8 (local.get $depth) (i32.add (local.get $was_newline) (i32.const 1)))
          (local.tee $write_idx (i32.sub (local.get $write_idx) (local.get $space_count)))
          (i32.store8 (i32.const 10)) ;; todo: crlf
          (memory.fill
            (local.tee $write_idx (i32.add (local.get $write_idx) (i32.const 1)))
            (global.get $indent_char)
            (local.tee $space_count (i32.mul (global.get $indent_len) (local.get $indent)))
          )
          (local.set $write_idx (i32.add (local.get $write_idx) (local.get $space_count)))
          (local.set $in_ident (i32.const 0))
          (local.set $was_newline (i32.const 1))
        ) (else (if (i32.eq (local.get $byte) (i32.const 59)) (then
          ;; ';'
          (if (i32.eq (i32.load8_u offset=1 (local.get $read_idx)) (i32.const 59)) (then
            ;; ';;'
            (if (local.get $in_ident) (then
              (i32.store8 (local.get $write_idx) (i32.const 32))
              (local.set $write_idx (i32.add (local.get $write_idx) (i32.const 1)))
            ))
            (memory.fill (local.get $write_idx) (i32.const 59) (i32.const 2))
            (local.set $write_idx (i32.add (local.get $write_idx) (i32.const 2)))
            (local.set $read_idx (i32.add (local.get $read_idx) (i32.const 2)))
            (if (local.tee $space_count (i32.ne (i32.load8_u (local.get $read_idx)) (i32.const 32))) (then
              (i32.store8 (local.get $write_idx) (i32.const 32))
              (local.set $write_idx (i32.add (local.get $write_idx) (i32.const 1)))
            ))
            (local.set $in_comment (i32.const 1))
            (br $a)
          ))
        ) (else (if (i32.eq (i32.and (local.get $byte) (i32.const 254)) (i32.const 40)) (then
          ;; '(' | ')'
          (if (i32.eq (local.get $byte) (i32.const 40)) (then
            ;; '('
            (if (local.get $in_ident) (then
              (i32.store8 (local.get $write_idx) (i32.const 32))
              (local.set $write_idx (i32.add (local.get $write_idx) (i32.const 1)))
            ))
            (local.tee $depth (i32.add (local.get $depth) (i32.const 1)))
            (i32.store8 (i32.const 0))
            (i32.store8 (local.get $write_idx) (local.get $byte))
            (local.set $write_idx (i32.add (local.get $write_idx) (i32.const 1)))
            (local.set $space_count (i32.const 0))
          ) (else
            ;; ')'
            (if (i32.gt_u (i32.load8_u (local.get $depth)) (local.get $was_newline)) (then
              (local.set $indent (i32.sub (local.get $indent) (i32.const 1)))
              (if (local.get $was_newline) (then
                (local.set $write_idx (i32.sub (local.get $write_idx) (global.get $indent_len)))
              ) (else
                (local.tee $write_idx (i32.sub (local.get $write_idx) (local.get $space_count)))
                (i32.store8 (i32.const 10)) ;; todo: crlf
                (memory.fill
                  (local.tee $write_idx (i32.add (local.get $write_idx) (i32.const 1)))
                  (global.get $indent_char)
                  (local.tee $space_count (i32.mul (global.get $indent_len) (local.get $indent)))
                )
                (local.set $write_idx (i32.add (local.get $write_idx) (local.get $space_count)))
              ))
            ) (else
              (local.set $indent (i32.sub (local.get $indent) (local.get $was_newline)))
              (local.set $write_idx (i32.sub (local.get $write_idx) (i32.add (local.get $was_newline) (local.get $space_count))))
            ))
            (local.set $depth (i32.sub (local.get $depth) (i32.const 1)))
            (i32.store8 (local.get $write_idx) (local.get $byte))
            (i32.store8 offset=1 (local.get $write_idx) (i32.const 32))
            (local.set $write_idx (i32.add (local.get $write_idx) (i32.const 2)))
            (local.set $space_count (i32.const 1))
          ))
          (local.set $in_ident (i32.const 0))
          (local.set $was_newline (i32.const 0))
        ) (else (if (i32.eq (local.get $byte) (i32.const 34)) (then
          ;; '"'
          (if (local.get $in_ident) (then
            (i32.store8 (local.get $write_idx) (i32.const 32))
            (local.set $write_idx (i32.add (local.get $write_idx) (i32.const 1)))
          ))
          (i32.store8 (local.get $write_idx) (local.get $byte))
          (local.set $write_idx (i32.add (local.get $write_idx) (i32.const 1)))
          (local.set $in_str (i32.const 1))
        ) (else
          ;; ident char
          (i32.store8 (local.get $write_idx) (local.get $byte))
          (local.set $write_idx (i32.add (local.get $write_idx) (i32.const 1)))
          (local.set $in_ident (i32.const 1))
          (local.set $space_count (i32.const 0))
          (local.set $was_newline (i32.const 0))
        ))))))))))
      ))))

      (local.tee $read_idx (i32.add (local.get $read_idx) (i32.const 1)))
      (br_if $a (i32.lt_u (local.get $read_end)))
    )

    (if (local.get $was_newline) (then) (else
      (if (i32.load8_u (local.get $depth)) (then) (else
        (i32.store8 (local.get $depth) (i32.const 1))
        (local.set $indent (i32.add (local.get $indent) (i32.const 1)))
      ))
      (local.tee $write_idx (i32.sub (local.get $write_idx) (local.get $space_count)))
      (i32.store8 (i32.const 10)) ;; todo: crlf
      (local.set $write_idx (i32.add (local.get $write_idx) (i32.const 1)))
    ))

    (global.set $output_len (i32.sub (local.get $write_idx) (global.get $output_start)))

    (i32.const 1)
  )

  (func (export "get_wasm_memory_buffer_size") (result i32)
    (global.get $buffer_size)
  )

  (func (export "get_wasm_memory_buffer") (result i32)
    (i32.const 0)
  )

  (func (export "clear_shared_bytes") (param $capacity i32)
    (global.set $shared_idx (global.get $shared_start))
  )

  (func (export "set_buffer_with_shared_bytes") (param $offset i32) (param $length i32)
    (memory.copy (i32.const 0) (i32.add (global.get $shared_start) (local.get $offset)) (local.get $length))
  )

  (func (export "add_to_shared_bytes_from_buffer") (param $length i32)
    (memory.copy (global.get $shared_idx) (i32.const 0) (local.get $length))
    (global.set $shared_idx (i32.add (global.get $shared_idx) (local.get $length)))
  )

  (func (export "get_plugin_schema_version") (result i32)
    (i32.const 3)
  )

  (func (export "set_global_config")
    (global.set $global_config_start (global.get $shared_start))
    (global.set $global_config_len (i32.sub (global.get $shared_idx) (global.get $shared_start)))
    (global.set $shared_start (global.get $shared_idx))
    (global.set $input_start (global.get $shared_idx))
  )

  (func (export "set_plugin_config")
    (global.set $plugin_config_start (global.get $shared_start))
    (global.set $plugin_config_len (i32.sub (global.get $shared_idx) (global.get $shared_start)))
    (global.set $shared_start (global.get $shared_idx))
    (global.set $input_start (global.get $shared_idx))
  )

  (data $empty_config_diagnostics "[]")
  (global $empty_config_diagnostics_len i32 (i32.const 2))

  (func (export "get_config_diagnostics") (result i32)
    (memory.init $empty_config_diagnostics (global.get $shared_start) (i32.const 0) (global.get $empty_config_diagnostics_len))
    (global.get $empty_config_diagnostics_len)
  )

  (func (export "get_resolved_config") (result i32)
    (memory.copy (global.get $shared_start) (global.get $plugin_config_start) (global.get $plugin_config_len))
    (global.get $plugin_config_len)
  )

  (data $license_text "todo: license")
  (global $license_text_len i32 (i32.const 13))

  (func (export "get_license_text") (result i32)
    (memory.init $license_text (global.get $shared_start) (i32.const 0) (global.get $license_text_len))
    (global.get $license_text_len)
  )

  (data $plugin_info "{\"name\":\"form.wat\",\"version\":\"0.0.0\",\"configKey\":\"wat\",\"fileExtensions\":[\"wat\"],\"helpUrl\":\"https://github.com/tjjfvi/form.wat\",\"configSchemaUrl\":\"\"}")
  (global $plugin_info_len i32 (i32.const 148))

  (func (export "get_plugin_info") (result i32)
    (memory.init $plugin_info (global.get $shared_start) (i32.const 0) (global.get $plugin_info_len))
    (global.get $plugin_info_len)
  )

  (func (export "set_file_path")
    (global.set $shared_start (global.get $input_start))
  )

  (func (export "set_override_config"))

  (func (export "format") (result i32)
    (global.set $input_start (global.get $shared_start))
    (global.set $input_len (i32.sub (global.get $shared_idx) (global.get $shared_start)))

    (global.set $output_start (global.get $input_start))
    (global.set $output_len (global.get $input_len))

    (call $format)
  )

  (func (export "get_formatted_text") (result i32)
    (global.set $shared_start (global.get $output_start))
    (global.get $output_len)
  )

  (func (export "get_error_text") (result i32)
    (global.set $shared_start (global.get $output_start))
    (global.get $output_len)
  )
)
