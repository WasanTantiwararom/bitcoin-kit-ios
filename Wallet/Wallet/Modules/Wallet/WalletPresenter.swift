import Foundation
import RxSwift

class WalletPresenter {

    let interactor: IWalletInteractor
    let router: IWalletRouter
    weak var view: IWalletView?

    var coinValues = [String: CoinValue]()
    var rates = [String: Double]()
    var progressSubjects = [String: BehaviorSubject<Double>]()
    var currency: Currency = DollarCurrency()

    var walletBalances = [WalletBalanceItem]()

    init(interactor: IWalletInteractor, router: IWalletRouter) {
        self.interactor = interactor
        self.router = router
    }

}

extension WalletPresenter: IWalletInteractorDelegate {

    func didInitialFetch(coinValues: [String: CoinValue], rates: [String: Double], progressSubjects: [String: BehaviorSubject<Double>], currency: Currency) {
        self.coinValues = coinValues
        self.rates = rates
        self.progressSubjects = progressSubjects
        self.currency = currency

        updateView()
    }

    func didUpdate(coinValue: CoinValue, adapterId: String) {
        coinValues[adapterId] = coinValue

        updateView()
    }

    func didUpdate(rates: [String: Double]) {
        self.rates = rates

        updateView()
    }

    private func updateView() {
        var totalBalance: Double = 0

        var viewItems = [WalletBalanceViewItem]()

        for (adapterId, coinValue) in coinValues {
            let rate = rates[coinValue.coin.code]

            viewItems.append(WalletBalanceViewItem(
                    coinValue: coinValue,
                    exchangeValue: rate.map { CurrencyValue(currency: currency, value: $0) },
                    currencyValue: rate.map { CurrencyValue(currency: currency, value: coinValue.value * $0) },
                    progressSubject: progressSubjects[adapterId]
            ))

            if let rate = rate {
                totalBalance += coinValue.value * rate
            }
        }

        view?.show(totalBalance: CurrencyValue(currency: currency, value: totalBalance))
        view?.show(walletBalances: viewItems)
    }

}

extension WalletPresenter: IWalletViewDelegate {

    func viewDidLoad() {
        interactor.notifyWalletBalances()
    }

    func refresh() {
        print("on refresh")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
            self.view?.didRefresh()
        })
    }

    func onReceive(for index: Int) {
        if index < walletBalances.count {
            router.onReceive(for: walletBalances[index])
        } else {
            router.onReceive(for: WalletBalanceItem(coinValue: CoinValue(coin: Bitcoin(), value: 10), exchangeRate: 2000, currency: DollarCurrency()))
            //test stab
        }
    }

    func onPay(for index: Int) {
        if index < walletBalances.count {
            router.onSend(for: walletBalances[index])
        } else {
            router.onSend(for: WalletBalanceItem(coinValue: CoinValue(coin: Bitcoin(), value: 10), exchangeRate: 12, currency: DollarCurrency()))
        }
    }

}
