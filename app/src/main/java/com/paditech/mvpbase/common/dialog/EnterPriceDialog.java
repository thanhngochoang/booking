package com.paditech.mvpbase.common.dialog;

import androidx.fragment.app.FragmentManager;
import android.view.View;
import android.widget.TextView;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.base.BaseDialog;
import com.paditech.mvpbase.common.view.PriceEditText;

import butterknife.BindView;
import butterknife.OnClick;

/**
 * Created by ThanhNgocHoang on 12/22/2017.
 */

public class EnterPriceDialog extends BaseDialog {
    @BindView(R.id.tv_title)
    TextView tvTitle;
    @BindView(R.id.tv_price)
    PriceEditText tvPrice;

    private SelectItemDialog.OnSelectPriceListener mOnSelectPriceListener;

    public static void show(FragmentManager manager, SelectItemDialog.OnSelectPriceListener listener) {
        EnterPriceDialog enterPriceDialog = new EnterPriceDialog();
        enterPriceDialog.mOnSelectPriceListener = listener;
        enterPriceDialog.show(manager, enterPriceDialog.getClass().getSimpleName());
    }

    @Override
    protected int getContentView() {
        return R.layout.dialog_enter_price;
    }

    @Override
    protected void initView(View view) {

    }

    @OnClick({R.id.btn_ok, R.id.btn_cancel})
    public void onViewClicked(View view) {
        switch (view.getId()) {
            case R.id.btn_ok:
                if (mOnSelectPriceListener != null)
                    mOnSelectPriceListener.onSelectPrice(tvPrice.getPrice());
                dismiss();
                break;
            case R.id.btn_cancel:
                dismiss();
                break;
        }
    }
}
