package com.paditech.mvpbase.common.view;

import android.content.Context;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.AttributeSet;
import android.widget.EditText;

import java.text.NumberFormat;
import java.util.Locale;

/**
 * Created by ThanhNgocHoang on 12/11/2017.
 */

public class PriceEditText extends android.support.v7.widget.AppCompatEditText {
    public PriceEditText(Context context) {
        super(context);
        initView();
    }

    public PriceEditText(Context context, AttributeSet attrs) {
        super(context, attrs);
        initView();
    }

    public PriceEditText(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        initView();
    }

    private String current = "";
    private long price;

    private void initView() {
        addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {

            }

            @Override
            public void onTextChanged(CharSequence charSequence, int start, int before, int count) {
                try {
                    if (!charSequence.toString().equals(current)) {
                        removeTextChangedListener(this);

                        String cleanString = charSequence.toString().replaceAll("[,.]", "");

                        double parsed = Double.parseDouble(cleanString);
                        String formatted = NumberFormat.getNumberInstance(Locale.GERMAN).format(parsed);

                        current = formatted;
                        setText(formatted);
                        setSelection(formatted.length());

                        addTextChangedListener(this);

                        try {
                            price = Long.parseLong(formatted.replaceAll("[,.]", ""));
                        } catch (Exception e) {
                            e.printStackTrace();
                        }
                    }
                } catch (Exception ignored) {
                    addTextChangedListener(this);
                }
            }

            @Override
            public void afterTextChanged(Editable s) {

            }
        });
    }

    public long getPrice() {
        return price;
    }
}
